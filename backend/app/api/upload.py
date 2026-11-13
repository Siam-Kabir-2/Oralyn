"""Bound multipart requests and validate decoded image resources."""

import io
from dataclasses import dataclass

from fastapi import HTTPException, UploadFile
from PIL import Image
from starlette.responses import JSONResponse


TOO_LARGE_DETAIL = "Image too large. Maximum size is 10 MB."


class RequestSizeLimitMiddleware:
    def __init__(self, app, max_request_bytes: int):
        self.app = app
        self.max_request_bytes = max_request_bytes

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("path") not in {
            "/predict", "/screenings"
        }:
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))
        declared = headers.get(b"content-length")
        if declared is not None:
            try:
                if int(declared) > self.max_request_bytes:
                    await JSONResponse({"detail": TOO_LARGE_DETAIL}, status_code=413)(
                        scope, receive, send
                    )
                    return
            except ValueError:
                pass

        received = 0
        chunks = []
        while True:
            message = await receive()
            if message["type"] != "http.request":
                return
            chunk = message.get("body", b"")
            received += len(chunk)
            if received > self.max_request_bytes:
                await JSONResponse({"detail": TOO_LARGE_DETAIL}, status_code=413)(
                    scope, receive, send
                )
                return
            chunks.append(chunk)
            if not message.get("more_body", False):
                break

        # Replay only a bounded body to Starlette's multipart parser. This
        # also covers chunked requests without Content-Length.
        body = b"".join(chunks)
        chunks.clear()
        replayed = False

        async def bounded_receive():
            nonlocal replayed
            if not replayed:
                replayed = True
                return {"type": "http.request", "body": body, "more_body": False}
            return {"type": "http.disconnect"}

        await self.app(scope, bounded_receive, send)


@dataclass
class ValidatedImage:
    image: Image.Image
    contents: bytes
    content_type: str
    extension: str


async def read_valid_image_payload(upload: UploadFile, settings) -> ValidatedImage:
    if not upload.content_type:
        raise HTTPException(status_code=400, detail="Unknown file type")
    if not upload.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted")

    try:
        contents = await upload.read(settings.max_image_bytes + 1)
    finally:
        await upload.close()
    if len(contents) > settings.max_image_bytes:
        raise HTTPException(status_code=413, detail=TOO_LARGE_DETAIL)

    try:
        with Image.open(io.BytesIO(contents)) as opened:
            if opened.width * opened.height > settings.max_image_pixels:
                raise HTTPException(
                    status_code=413,
                    detail="Decoded image is too large for screening.",
                )
            opened.load()
            image_format = (opened.format or "").upper()
            detected = {
                "JPEG": ("image/jpeg", "jpg"),
                "PNG": ("image/png", "png"),
                "WEBP": ("image/webp", "webp"),
                "BMP": ("image/bmp", "bmp"),
            }.get(image_format)
            if detected is None:
                raise HTTPException(
                    status_code=400, detail="Unsupported image format"
                )
            return ValidatedImage(
                image=opened.copy(),
                contents=contents,
                content_type=detected[0],
                extension=detected[1],
            )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file") from None


async def read_valid_image(upload: UploadFile, settings) -> Image.Image:
    return (await read_valid_image_payload(upload, settings)).image
