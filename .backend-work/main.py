import base64
import io
import logging
import os
import secrets
import threading

import numpy as np
import torch
import torch.nn as nn

from PIL import Image
from dotenv import load_dotenv

from fastapi import (
    FastAPI,
    UploadFile,
    File,
    Header,
    HTTPException,
)
from fastapi.middleware.cors import CORSMiddleware

from torchvision import transforms
from torchvision.models import resnet50
from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.image import show_cam_on_image
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget


load_dotenv()

logger = logging.getLogger(__name__)


# -------------------------------------------------
# Configuration
# -------------------------------------------------

API_KEY = os.getenv("ORALYN_API_KEY")

if not API_KEY:
    raise RuntimeError(
        "ORALYN_API_KEY is not configured"
    )

PRIMARY_MODEL_PATH = "models/resnet50_smartom_best.pth"
VERIFICATION_MODEL_PATH = "models/resnet50_bmiocd_binary_best.pth"

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

device = torch.device("cpu")


# -------------------------------------------------
# FastAPI
# -------------------------------------------------

app = FastAPI(
    title="Oralyn AI API",
    version="1.0"
)

# Permit only this local Flutter Web preview to call the tunneled API.
# Authentication is still enforced by x-api-key on /predict.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:8081"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "x-api-key"],
)


# -------------------------------------------------
# Model loading
# -------------------------------------------------

def load_model(model_path: str):

    checkpoint = torch.load(
        model_path,
        map_location=device,
        weights_only=False
    )

    classes = checkpoint["classes"]
    class_to_idx = checkpoint["class_to_idx"]

    model = resnet50(weights=None)
    model.fc = nn.Linear(
        model.fc.in_features,
        len(classes)
    )
    model.load_state_dict(
        checkpoint["model_state_dict"]
    )
    model.to(device)
    model.eval()

    return model, classes, class_to_idx


primary_model, primary_classes, primary_class_to_idx = load_model(
    PRIMARY_MODEL_PATH
)
verification_model, verification_classes, verification_class_to_idx = load_model(
    VERIFICATION_MODEL_PATH
)

# Grad-CAM is attached only to the primary four-class model. The lock keeps
# hook state isolated when multiple requests arrive at the same time.
primary_gradcam = GradCAM(
    model=primary_model,
    target_layers=[primary_model.layer4[-1]]
)
gradcam_lock = threading.Lock()


# -------------------------------------------------
# Preprocessing
# Same preprocessing used during validation/testing
# -------------------------------------------------

image_transform = transforms.Compose([
    transforms.Resize((224, 224)),

    transforms.ToTensor(),

    transforms.Normalize(
        mean=[
            0.485,
            0.456,
            0.406
        ],
        std=[
            0.229,
            0.224,
            0.225
        ]
    )
])


def preprocess_image(pil_image: Image.Image):

    return image_transform(
        pil_image.convert("RGB")
    ).unsqueeze(0).to(device)


def _format_predictions(probabilities, classes):

    sorted_probs, sorted_indices = torch.sort(
        probabilities,
        descending=True
    )

    return [
        {
            "class": classes[index.item()],
            "score": round(probability.item(), 4)
        }
        for probability, index in zip(
            sorted_probs,
            sorted_indices
        )
    ]


def predict_multiclass(image_tensor):

    with torch.inference_mode():
        output = primary_model(image_tensor)
        probabilities = torch.softmax(output, dim=1)[0]

    return _format_predictions(
        probabilities,
        primary_classes
    )


def predict_binary(image_tensor):

    with torch.inference_mode():
        output = verification_model(image_tensor)
        probabilities = torch.softmax(output, dim=1)[0]

    return _format_predictions(
        probabilities,
        verification_classes
    )


def generate_gradcam(
    model,
    input_tensor,
    target_class: int
):

    if model is not primary_model:
        raise ValueError(
            "Grad-CAM is supported only for the primary model"
        )

    targets = [
        ClassifierOutputTarget(target_class)
    ]

    with gradcam_lock:
        grayscale_cam = primary_gradcam(
            input_tensor=input_tensor,
            targets=targets
        )[0]

    return np.asarray(
        grayscale_cam,
        dtype=np.float32
    )


def overlay_gradcam(
    pil_image: Image.Image,
    heatmap: np.ndarray
):

    original = pil_image.convert("RGB")

    heatmap_image = Image.fromarray(
        np.uint8(np.clip(heatmap, 0, 1) * 255),
        mode="L"
    ).resize(
        original.size,
        Image.Resampling.BILINEAR
    )

    resized_heatmap = (
        np.asarray(heatmap_image, dtype=np.float32) / 255.0
    )
    original_array = (
        np.asarray(original, dtype=np.float32) / 255.0
    )

    overlay = show_cam_on_image(
        original_array,
        resized_heatmap,
        use_rgb=True,
        image_weight=0.68
    )

    return Image.fromarray(overlay)


def encode_image_base64(
    pil_image: Image.Image
):

    buffer = io.BytesIO()
    pil_image.convert("RGB").save(
        buffer,
        format="JPEG",
        quality=88,
        optimize=True
    )

    encoded = base64.b64encode(
        buffer.getvalue()
    ).decode("ascii")

    return f"data:image/jpeg;base64,{encoded}"


def determine_screening_status(
    primary_prediction: str,
    verification_prediction: str | None = None
):

    if primary_prediction == "Normal":
        return "Low Concern"

    if primary_prediction == "Variation_from_Normal":
        return "Review Recommended"

    if primary_prediction in {"OPMD", "Oral_Cancer"}:
        if verification_prediction == "Cancer":
            return "Prompt Specialist Review"
        return "Professional Review Recommended"

    raise ValueError(
        f"Unsupported primary prediction: {primary_prediction}"
    )


# -------------------------------------------------
# API key verification
# -------------------------------------------------

def verify_key(x_api_key: str | None):

    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API key required"
        )

    if not secrets.compare_digest(
        x_api_key,
        API_KEY
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid API key"
        )


# -------------------------------------------------
# Health
# -------------------------------------------------

@app.get("/")
def root():

    return {
        "status": "online",
        "service": "Oralyn AI",
        "model": "ResNet50"
    }


@app.get("/health")
def health():

    return {
        "status": "healthy"
    }


# -------------------------------------------------
# Prediction
# -------------------------------------------------

@app.post("/predict")
async def predict(
    image: UploadFile = File(...),
    x_api_key: str | None = Header(default=None)
):

    verify_key(x_api_key)


    # Check content type
    if not image.content_type:

        raise HTTPException(
            status_code=400,
            detail="Unknown file type"
        )

    if not image.content_type.startswith("image/"):

        raise HTTPException(
            status_code=400,
            detail="Only image files are accepted"
        )


    contents = await image.read()


    # Check upload size
    if len(contents) > MAX_IMAGE_SIZE:

        raise HTTPException(
            status_code=413,
            detail="Image too large. Maximum size is 10 MB."
        )


    try:

        pil_image = Image.open(
            io.BytesIO(contents)
        )

    except Exception:

        raise HTTPException(
            status_code=400,
            detail="Invalid image file"
        )


    image_tensor = preprocess_image(pil_image)

    primary_predictions = predict_multiclass(
        image_tensor
    )
    primary_prediction = primary_predictions[0]["class"]
    primary_score = primary_predictions[0]["score"]

    gradcam = {
        "available": False
    }

    try:
        target_class = primary_class_to_idx[
            primary_prediction
        ]
        heatmap = generate_gradcam(
            primary_model,
            image_tensor,
            target_class
        )
        overlay_image = overlay_gradcam(
            pil_image,
            heatmap
        )
        gradcam = {
            "available": True,
            "label": "Area highlighted for review",
            "image_base64": encode_image_base64(
                overlay_image
            )
        }
    except Exception:
        logger.exception(
            "Grad-CAM generation failed; returning prediction without overlay"
        )

    verification_prediction = None
    cancer_verification = {
        "performed": False
    }

    if primary_prediction in {"OPMD", "Oral_Cancer"}:
        verification_predictions = predict_binary(
            image_tensor
        )
        verification_prediction = verification_predictions[0]["class"]

        cancer_verification = {
            "performed": True,
            "prediction": verification_prediction,
            "score": verification_predictions[0]["score"],
            "predictions": verification_predictions
        }

    screening_status = determine_screening_status(
        primary_prediction,
        verification_prediction
    )

    return {
        "primary_prediction": primary_prediction,
        "primary_score": primary_score,
        "primary_predictions": primary_predictions,
        "cancer_verification": cancer_verification,
        "gradcam": gradcam,
        "screening_status": screening_status,
        "model": {
            "primary": "ResNet50 SMART-OM 4-class",
            "verification": "ResNet50 BMIOCD binary"
        },
        "disclaimer": (
            "AI-assisted research screening only. "
            "This result is not a clinical diagnosis."
        )
    }
