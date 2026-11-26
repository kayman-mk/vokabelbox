import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PORT = "18081"
PROJECT = f"vokabelhain-test-{uuid.uuid4().hex[:8]}"


def main():
    if shutil.which("docker"):
        compose = ["docker", "compose"]
    elif shutil.which("podman"):
        compose = ["podman", "compose"]
    else:
        raise SystemExit("Docker Compose or Podman Compose is required to run infrastructure tests.")

    environment = os.environ.copy()
    environment.update({
        "APP_PORT": PORT,
        "MYSQL_DATABASE": "vokabelhain_test",
        "MYSQL_USER": "vokabelhain_test",
        "MYSQL_PASSWORD": "isolated-test-database-password",
        "MYSQL_ROOT_PASSWORD": "isolated-test-root-password",
        "DEV_ADMIN_USERNAME": "test",
        "DEV_ADMIN_PASSWORD": "test",
        "API_BASE_URL": f"http://localhost:{PORT}",
    })

    def run_compose(*args):
        subprocess.run(compose + ["-p", PROJECT, *args], cwd=ROOT, env=environment, check=True)

    try:
        run_compose("up", "--build", "-d")
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(f"{environment['API_BASE_URL']}/api/v1/health", timeout=3) as response:
                    if response.status == 200:
                        break
            except (OSError, urllib.error.URLError):
                time.sleep(2)
        else:
            raise RuntimeError("Isolated test stack did not become healthy within three minutes.")

        subprocess.run([sys.executable, str(ROOT / "tests" / "infra_test.py")], cwd=ROOT, env=environment, check=True)
    finally:
        run_compose("down", "--rmi", "local", "--volumes", "--remove-orphans")


if __name__ == "__main__":
    main()
