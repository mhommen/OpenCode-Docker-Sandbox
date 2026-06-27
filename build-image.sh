#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-opencode-sandbox}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTEXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker is not installed or not in PATH" >&2
    exit 1
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

if [[ -z "${HOST_UID}" || -z "${HOST_GID}" ]]; then
    echo "error: could not determine HOST_UID/HOST_GID" >&2
    exit 1
fi

echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} with HOST_UID=${HOST_UID} HOST_GID=${HOST_GID}"

docker build \
    --build-arg "HOST_UID=${HOST_UID}" \
    --build-arg "HOST_GID=${HOST_GID}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${CONTEXT_DIR}"

echo "==> Done. Start with:"
echo "    docker run -it --rm -v \"\$PWD\":/source ${IMAGE_NAME}:${IMAGE_TAG}"