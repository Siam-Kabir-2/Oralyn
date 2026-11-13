"""Primary-model attention rendering, guarded against concurrent hook access."""

import base64
import io

import numpy as np
from PIL import Image
from pytorch_grad_cam import GradCAM
from pytorch_grad_cam.utils.image import show_cam_on_image
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget


class GradCamRenderer:
    def __init__(self, inference):
        self.inference = inference
        self.primary_gradcam = GradCAM(
            model=inference.primary_model,
            target_layers=[inference.primary_model.layer4[-1]],
        )

    def render(self, image: Image.Image, image_tensor, target_class: int) -> str:
        targets = [ClassifierOutputTarget(target_class)]
        with self.inference.primary_lock:
            grayscale_cam = self.primary_gradcam(
                input_tensor=image_tensor, targets=targets
            )[0]
        heatmap = np.asarray(grayscale_cam, dtype=np.float32)
        overlay = self._overlay(image, heatmap)
        return self._encode(overlay)

    @staticmethod
    def _overlay(image: Image.Image, heatmap: np.ndarray) -> Image.Image:
        original = image.convert("RGB")
        heatmap_image = Image.fromarray(
            np.uint8(np.clip(heatmap, 0, 1) * 255), mode="L"
        ).resize(original.size, Image.Resampling.BILINEAR)
        resized_heatmap = np.asarray(heatmap_image, dtype=np.float32) / 255.0
        original_array = np.asarray(original, dtype=np.float32) / 255.0
        overlay = show_cam_on_image(
            original_array, resized_heatmap, use_rgb=True, image_weight=0.68
        )
        return Image.fromarray(overlay)

    @staticmethod
    def _encode(image: Image.Image) -> str:
        buffer = io.BytesIO()
        image.convert("RGB").save(buffer, format="JPEG", quality=88, optimize=True)
        encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
        return f"data:image/jpeg;base64,{encoded}"
