"""The existing two-model decision chain and public guidance mapping."""

import logging

from PIL import Image

from app.schemas.prediction import GradCamResult, PredictionResponse, VerificationResult


logger = logging.getLogger(__name__)


def determine_screening_status(
    primary_prediction: str, verification_prediction: str | None = None
) -> str:
    if primary_prediction == "Normal":
        return "Low Concern"
    if primary_prediction == "Variation_from_Normal":
        return "Review Recommended"
    if primary_prediction in {"OPMD", "Oral_Cancer"}:
        if verification_prediction == "Cancer":
            return "Prompt Specialist Review"
        return "Professional Review Recommended"
    raise ValueError("Unsupported primary prediction")


class ScreeningService:
    def __init__(self, inference, gradcam):
        self.inference = inference
        self.gradcam = gradcam

    def screen(self, image: Image.Image) -> PredictionResponse:
        image_tensor = self.inference.preprocess(image)
        primary_predictions = self.inference.predict_primary(image_tensor)
        primary_prediction = primary_predictions[0]["class"]
        primary_score = primary_predictions[0]["score"]

        gradcam: GradCamResult = {"available": False}
        try:
            target_class = self.inference.primary_class_to_idx[primary_prediction]
            overlay = self.gradcam.render(image, image_tensor, target_class)
            gradcam = {
                "available": True,
                "label": "Area highlighted for review",
                "image_base64": overlay,
            }
        except Exception as error:
            # No uploaded filename, image bytes, token or exception message in logs.
            logger.warning("gradcam_unavailable error_type=%s", type(error).__name__)

        verification_prediction = None
        cancer_verification: VerificationResult = {"performed": False}
        if primary_prediction in {"OPMD", "Oral_Cancer"}:
            verification_predictions = self.inference.predict_verification(image_tensor)
            verification_prediction = verification_predictions[0]["class"]
            cancer_verification = {
                "performed": True,
                "prediction": verification_prediction,
                "score": verification_predictions[0]["score"],
                "predictions": verification_predictions,
            }

        return {
            "primary_prediction": primary_prediction,
            "primary_score": primary_score,
            "primary_predictions": primary_predictions,
            "cancer_verification": cancer_verification,
            "gradcam": gradcam,
            "screening_status": determine_screening_status(
                primary_prediction, verification_prediction
            ),
            "model": {
                "primary": "ResNet50 SMART-OM 4-class",
                "verification": "ResNet50 BMIOCD binary",
            },
            "disclaimer": (
                "AI-assisted research screening only. "
                "This result is not a clinical diagnosis."
            ),
        }
