#!/usr/bin/env bash
set -euo pipefail

SERVICE="kokoro-fastapi.service"
CONTAINER="kokoro-fastapi"
ENV_FILE="${HOME}/.config/kokoro-fastapi.env"
CPU_IMAGE="ghcr.io/remsky/kokoro-fastapi-cpu:latest"
GPU_IMAGE="ghcr.io/remsky/kokoro-fastapi-gpu:latest"

if ! command -v docker >/dev/null 2>&1; then
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  exit 0
fi

target_mode="cpu"
target_image="${CPU_IMAGE}"
target_args=""

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  if docker info --format '{{range $name, $_ := .Runtimes}}{{$name}} {{end}}' 2>/dev/null | grep -q 'nvidia'; then
    target_mode="gpu"
    target_image="${GPU_IMAGE}"
    target_args="--gpus all"
  fi
fi

mkdir -p "$(dirname "${ENV_FILE}")"
{
  printf 'KOKORO_MODE=%s\n' "${target_mode}"
  printf 'KOKORO_IMAGE=%s\n' "${target_image}"
  printf 'KOKORO_DOCKER_ARGS=%s\n' "${target_args}"
} >"${ENV_FILE}"

current_mode="unknown"

if systemctl --user is-active --quiet "${SERVICE}"; then
  current_image="$(docker inspect -f '{{.Config.Image}}' "${CONTAINER}" 2>/dev/null || true)"
  case "${current_image}" in
    "${GPU_IMAGE}") current_mode="gpu" ;;
    "${CPU_IMAGE}") current_mode="cpu" ;;
    *) current_mode="${target_mode}" ;;
  esac
fi

if [[ "${current_mode}" != "${target_mode}" ]]; then
  systemctl --user restart "${SERVICE}"
fi
