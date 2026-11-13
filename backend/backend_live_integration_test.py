"""Launch the tracked ASGI app with real checkpoints on a local test port."""

import io
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import httpx
from PIL import Image


backend_root = Path(__file__).resolve().parent
model_root = Path(os.getenv("ORALYN_MODEL_DIR", backend_root / "models"))
assert model_root.is_dir(), "Set ORALYN_MODEL_DIR to the local checkpoint directory"

with socket.socket() as probe:
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]

environment = os.environ.copy()
issuer = os.getenv("CLERK_ISSUER", "")
session_token = os.getenv("ORALYN_TEST_SESSION_TOKEN", "")
assert issuer and session_token, "Set CLERK_ISSUER and ORALYN_TEST_SESSION_TOKEN for live integration"
environment["CLERK_ISSUER"] = issuer
environment["ORALYN_MODEL_DIR"] = str(model_root)
environment.pop("ORALYN_ENV_FILE", None)
command = [
    sys.executable,
    "-m",
    "uvicorn",
    "main:app",
    "--host",
    "127.0.0.1",
    "--port",
    str(port),
]
process = subprocess.Popen(
    command,
    cwd=backend_root,
    env=environment,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
)
try:
    base_url = f"http://127.0.0.1:{port}"
    with httpx.Client(base_url=base_url, timeout=10.0) as client:
        # Cold Windows/CPU model loads can exceed 35 seconds under Gradle load.
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise AssertionError("Uvicorn exited before model readiness")
            try:
                ready = client.get("/health")
                if ready.status_code == 200:
                    break
            except httpx.TransportError:
                pass
            time.sleep(0.25)
        else:
            raise AssertionError("Uvicorn did not report model readiness")

        buffer = io.BytesIO()
        Image.new("RGB", (256, 256), (180, 120, 115)).save(buffer, "PNG")
        response = client.post(
            "/predict",
            headers={"authorization": f"Bearer {session_token}"},
            files={"image": ("synthetic.png", buffer.getvalue(), "image/png")},
        )
        assert response.status_code == 200, response.status_code
        result = response.json()
        assert result["gradcam"]["available"] is True
        assert result["primary_prediction"] in {
            "Normal", "Variation_from_Normal", "OPMD", "Oral_Cancer"
        }
        assert result["cancer_verification"]["performed"] is (
            result["primary_prediction"] in {"OPMD", "Oral_Cancer"}
        )
        print("uvicorn_health_status=200")
        print("uvicorn_predict_status=200")
        print("uvicorn_real_gradcam_available=true")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
