import asyncio
import io
import os
from pathlib import Path
import sys

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

print("invalid_image_status=400")
print("gradcam_failure_prediction_status=200")
print("gradcam_failure_available=false")
