"""Typed shape of the existing /predict JSON response."""

from typing import NotRequired, TypedDict


ClassScore = TypedDict("ClassScore", {"class": str, "score": float})


class ModelNames(TypedDict):
    primary: str
    verification: str


class VerificationResult(TypedDict):
    performed: bool
    prediction: NotRequired[str]
    score: NotRequired[float]
    predictions: NotRequired[list[ClassScore]]


class GradCamResult(TypedDict):
    available: bool
    label: NotRequired[str]
    image_base64: NotRequired[str]


class PredictionResponse(TypedDict):
    primary_prediction: str
    primary_score: float
    primary_predictions: list[ClassScore]
    cancer_verification: VerificationResult
    gradcam: GradCamResult
    screening_status: str
    model: ModelNames
    disclaimer: str
