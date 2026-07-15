#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-NotchHero}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${PWD}/.build/module-cache}"

child_pid=""
last_signature=""

mkdir -p "${CLANG_MODULE_CACHE_PATH}"

cleanup() {
  if [[ -n "${child_pid}" ]] && kill -0 "${child_pid}" 2>/dev/null; then
    kill "${child_pid}" 2>/dev/null || true
    wait "${child_pid}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

signature() {
  find Package.swift Sources -type f \( -name '*.swift' -o -name '*.json' -o -name '*.plist' \) -print0 \
    | xargs -0 stat -f '%m %z %N' \
    | shasum
}

start_app() {
  cleanup
  echo "[dev] starting ${APP_NAME}"
  env \
    DEVELOPER_DIR="${DEVELOPER_DIR}" \
    CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH}" \
    swift run "${APP_NAME}" &
  child_pid="$!"
}

last_signature="$(signature)"
start_app

while true; do
  sleep "${POLL_INTERVAL}"
  next_signature="$(signature)"
  if [[ "${next_signature}" != "${last_signature}" ]]; then
    last_signature="${next_signature}"
    echo "[dev] change detected, restarting"
    start_app
  fi
done
