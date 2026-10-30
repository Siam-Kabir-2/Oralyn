"""Checkpoint loading and preprocessing preserved from the prototype."""

import threading
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image
from torchvision import transforms
from torchvision.models import resnet50


def _load_model(model_path: Path, device):
    # The shipped checkpoints contain plain metadata and tensors, so restrict
    # deserialization to weights and safe built-in values.
    checkpoint = torch.load(model_path, map_location=device, weights_only=True)
    classes = checkpoint["classes"]
    class_to_idx = checkpoint["class_to_idx"]
    model = resnet50(weights=None)
    model.fc = nn.Linear(model.fc.in_features, len(classes))
    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(device)
    model.eval()
    return model, classes, class_to_idx


def _format_predictions(probabilities, classes):
    sorted_probs, sorted_indices = torch.sort(probabilities, descending=True)
    return [
        {"class": classes[index.item()], "score": round(probability.item(), 4)}
        for probability, index in zip(sorted_probs, sorted_indices)
    ]


class ModelInference:
    def __init__(
        self,
        primary_model,
        primary_classes,
        primary_class_to_idx,
        verification_model,
        verification_classes,
        verification_class_to_idx,
        device,
    ):
        self.primary_model = primary_model
        self.primary_classes = primary_classes
        self.primary_class_to_idx = primary_class_to_idx
        self.verification_model = verification_model
        self.verification_classes = verification_classes
        self.verification_class_to_idx = verification_class_to_idx
        self.device = device
        # Grad-CAM installs hooks on the primary model. Share its lock with
        # primary inference so concurrent forwards cannot mutate hook state.
        self.primary_lock = threading.Lock()
        self.image_transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225],
                ),
            ]
        )

    @classmethod
    def load(cls, model_dir: Path) -> "ModelInference":
        device = torch.device("cpu")
        primary = _load_model(model_dir / "resnet50_smartom_best.pth", device)
        verification = _load_model(
            model_dir / "resnet50_bmiocd_binary_best.pth", device
        )
        return cls(*primary, *verification, device)

    def preprocess(self, image: Image.Image):
        return self.image_transform(image.convert("RGB")).unsqueeze(0).to(self.device)

    def predict_primary(self, image_tensor):
        with self.primary_lock, torch.inference_mode():
            output = self.primary_model(image_tensor)
            probabilities = torch.softmax(output, dim=1)[0]
        return _format_predictions(probabilities, self.primary_classes)

    def predict_verification(self, image_tensor):
        with torch.inference_mode():
            output = self.verification_model(image_tensor)
            probabilities = torch.softmax(output, dim=1)[0]
        return _format_predictions(probabilities, self.verification_classes)
