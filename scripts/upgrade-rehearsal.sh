#!/bin/sh
set -eu

REHEARSAL_APPLY="${REHEARSAL_APPLY:-0}"

echo "Running local checks before any rehearsal deploy ..."
just check

if [ "${REHEARSAL_APPLY}" != "1" ]; then
  echo "Skipping deployment because REHEARSAL_APPLY=${REHEARSAL_APPLY}."
  echo "Set REHEARSAL_APPLY=1 and provide TARGET_HOST/TAILNET_HOST to apply to a rehearsal node."
  exit 0
fi

TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required when REHEARSAL_APPLY=1}"

echo "Checking local Tailscale status ..."
tailscale status --self

echo "Deploying rehearsal target over Tailscale: ${TARGET_HOST}"
NODE_NAME="${NODE_NAME:-cloud-edge-1}" \
TARGET_HOST="${TARGET_HOST}" \
DEPLOY_USER="${DEPLOY_USER:-nixos}" \
IDENTITY_FILE="${IDENTITY_FILE:-}" \
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-}" \
SOPS_AGE_KEY="${SOPS_AGE_KEY:-}" \
SOPS_AGE_KEY_PASS_ENTRY="${SOPS_AGE_KEY_PASS_ENTRY:-sops/age-key}" \
"$(dirname "$0")/deploy.sh"

echo "Validating rehearsal target over Tailscale: ${TARGET_HOST}"
TARGET_HOST="${TARGET_HOST}" \
DEPLOY_USER="${DEPLOY_USER:-nixos}" \
IDENTITY_FILE="${IDENTITY_FILE:-}" \
"$(dirname "$0")/validate.sh"
