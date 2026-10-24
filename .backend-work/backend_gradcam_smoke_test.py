import asyncio
import io
import os
from pathlib import Path
import sys

import numpy as np

from fastapi import HTTPException, UploadFile
from PIL import Image
from starlette.datastructures import Headers

backend_root = Path(
    os.environ.get("ORALYN_BACKEND_ROOT", r"D:\oralyn-backend")
)
sys.path.insert(0, str(backend_root))
import main


invalid_upload = UploadFile(
    file=io.BytesIO(b"not an image"),
    filename="invalid.png",
    headers=Headers({"content-type": "image/png"}),
)
try:
    asyncio.run(main.predict(invalid_upload, main.API_KEY))
except HTTPException as error:
    assert error.status_code == 400
else:
    raise AssertionError("Invalid image was accepted")

original_generate_gradcam = main.generate_gradcam


def fail_gradcam(*_args, **_kwargs):
    raise RuntimeError("intentional smoke-test failure")


main.generate_gradcam = fail_gradcam
image_buffer = io.BytesIO()
Image.new("RGB", (256, 256), color=(180, 120, 115)).save(
    image_buffer,
    format="PNG",
)
upload = UploadFile(
    file=io.BytesIO(image_buffer.getvalue()),
    filename="generated-smoke-test.png",
    headers=Headers({"content-type": "image/png"}),
)
response = asyncio.run(main.predict(upload, main.API_KEY))

main.generate_gradcam = original_generate_gradcam
payload = response
assert payload["gradcam"] == {"available": False}, payload["gradcam"]
assert payload["primary_prediction"] in main.primary_classes

real_upload = UploadFile(
    file=io.BytesIO(image_buffer.getvalue()),
    filename="generated-smoke-test.png",
    headers=Headers({"content-type": "image/png"}),
)
real_payload = asyncio.run(main.predict(real_upload, main.API_KEY))
assert real_payload["gradcam"]["available"] is True
assert real_payload["gradcam"]["image_base64"].startswith(
    "data:image/jpeg;base64,"
)

print("invalid_image_status=400")
print("gradcam_failure_prediction_status=200")
print("gradcam_failure_available=false")
print("real_gradcam_available=true")


# Exercise the orchestration branches without relying on a synthetic image's
# unpredictable model classification. The original model functions are restored
# before the process exits.
original_multiclass = main.predict_multiclass
original_binary = main.predict_binary
original_gradcam = main.generate_gradcam
binary_calls = 0
primary_class = "Normal"


def stub_multiclass(_image_tensor):
    return [{"class": primary_class, "score": 0.8}]


def stub_binary(_image_tensor):
    global binary_calls
    binary_calls += 1
    return [{"class": "Cancer", "score": 0.7}]


def stub_gradcam(*_args, **_kwargs):
    return np.zeros((7, 7), dtype=np.float32)


def valid_upload():
    return UploadFile(
        file=io.BytesIO(image_buffer.getvalue()),
        filename="generated-smoke-test.png",
        headers=Headers({"content-type": "image/png"}),
    )


try:
    main.predict_multiclass = stub_multiclass
    main.predict_binary = stub_binary
    main.generate_gradcam = stub_gradcam

    for primary_class in ("Normal", "Variation_from_Normal"):
        payload = asyncio.run(main.predict(valid_upload(), main.API_KEY))
        assert payload["cancer_verification"] == {"performed": False}
        assert payload["gradcam"]["available"] is True
    assert binary_calls == 0

    primary_class = "OPMD"
    payload = asyncio.run(main.predict(valid_upload(), main.API_KEY))
    assert binary_calls == 1
    assert payload["cancer_verification"]["prediction"] == "Cancer"
    assert payload["screening_status"] == "Prompt Specialist Review"

    primary_class = "Oral_Cancer"
    payload = asyncio.run(main.predict(valid_upload(), main.API_KEY))
    assert binary_calls == 2
    assert payload["cancer_verification"]["performed"] is True
finally:
    main.predict_multiclass = original_multiclass
    main.predict_binary = original_binary
    main.generate_gradcam = original_gradcam

print("verification_skipped_for=Normal,Variation_from_Normal")
print("verification_performed_for=OPMD,Oral_Cancer")
print("gradcam_overlay_available=true")
