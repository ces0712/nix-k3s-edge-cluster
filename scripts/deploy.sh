#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

NODE_NAME="${NODE_NAME:-cloud-edge-1}"
TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
BOOTSTRAP_INSTALL_BOOTLOADER="${BOOTSTRAP_INSTALL_BOOTLOADER:-auto}"
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-}"
SOPS_AGE_KEY="${SOPS_AGE_KEY:-}"
SOPS_AGE_KEY_PASS_ENTRY="${SOPS_AGE_KEY_PASS_ENTRY:-sops/age-key}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${TARGET_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

LOCAL_UTC_NOW="$(date -u '+%Y-%m-%d %H:%M:%S')"

TMP_AGE_DIR=""
AGE_KEY_SOURCE_FILE=""
TMP_SSH_CONFIG=""

cleanup() {
  if [ -n "${TMP_AGE_DIR}" ] && [ -d "${TMP_AGE_DIR}" ]; then
    rm -rf "${TMP_AGE_DIR}"
  fi
  if [ -n "${TMP_SSH_CONFIG}" ] && [ -f "${TMP_SSH_CONFIG}" ]; then
    rm -f "${TMP_SSH_CONFIG}"
  fi
}

trap cleanup EXIT INT TERM

resolve_age_key_source() {
  if [ -n "${SOPS_AGE_KEY_FILE}" ]; then
    [ -f "${SOPS_AGE_KEY_FILE}" ] || die "SOPS_AGE_KEY_FILE does not exist: ${SOPS_AGE_KEY_FILE}"
    AGE_KEY_SOURCE_FILE="${SOPS_AGE_KEY_FILE}"
    return 0
  fi

  if [ -n "${SOPS_AGE_KEY}" ]; then
    TMP_AGE_DIR="$(mktemp -d)"
    AGE_KEY_SOURCE_FILE="${TMP_AGE_DIR}/age.key"
    printf '%s\n' "${SOPS_AGE_KEY}" > "${AGE_KEY_SOURCE_FILE}"
    chmod 600 "${AGE_KEY_SOURCE_FILE}"
    return 0
  fi

  if command -v pass >/dev/null 2>&1; then
    if AGE_KEY_FROM_PASS="$(pass show "${SOPS_AGE_KEY_PASS_ENTRY}" 2>/dev/null)"; then
      TMP_AGE_DIR="$(mktemp -d)"
      AGE_KEY_SOURCE_FILE="${TMP_AGE_DIR}/age.key"
      printf '%s\n' "${AGE_KEY_FROM_PASS}" > "${AGE_KEY_SOURCE_FILE}"
      chmod 600 "${AGE_KEY_SOURCE_FILE}"
      return 0
    fi
  fi

  die "Unable to resolve a SOPS age key from file, env, or pass entry '${SOPS_AGE_KEY_PASS_ENTRY}'."
}

prepare_remote_time() {
  echo "Preparing remote clock on ${TARGET} ..."
  remote_run "${SSH_OPTS}" "${TARGET}" "REMOTE_UTC='${LOCAL_UTC_NOW}' sh -s" <<'EOF'
set -eu
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO date -u -s "$REMOTE_UTC" >/dev/null

if command -v timedatectl >/dev/null 2>&1; then
  $SUDO timedatectl set-ntp true >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  $SUDO systemctl restart systemd-timesyncd >/dev/null 2>&1 || true
fi

date -u '+remote time: %Y-%m-%d %H:%M:%S UTC'
EOF
}

push_age_key_to_target() {
  echo "Pushing stable SOPS age key to ${TARGET}:/var/lib/sops-nix/key.txt ..."
  cat "${AGE_KEY_SOURCE_FILE}" | remote_run "${SSH_OPTS}" "${TARGET}" '
set -eu
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi
$SUDO install -d -m 700 /var/lib/sops-nix
$SUDO tee /var/lib/sops-nix/key.txt >/dev/null
$SUDO chmod 600 /var/lib/sops-nix/key.txt
'
}

create_ssh_config() {
  TMP_SSH_CONFIG="$(mktemp)"
  {
    printf 'Host *\n'
    printf '  StrictHostKeyChecking accept-new\n'
    printf '  ConnectTimeout 10\n'
    if [ -n "${IDENTITY_FILE}" ]; then
      printf '  IdentitiesOnly yes\n'
      printf '  IdentityFile %s\n' "${IDENTITY_FILE}"
    fi
  } > "${TMP_SSH_CONFIG}"
}

run_colmena() {
  create_ssh_config
  SSH_CONFIG_FILE="${TMP_SSH_CONFIG}" TARGET_HOST="${TARGET_HOST}" DEPLOY_USER="${DEPLOY_USER}" nix shell .#colmena -c colmena apply --impure --on "${NODE_NAME}"
}

run_bootstrap_switch() {
  create_ssh_config

  ssh_target="${TARGET}"
  ssh_build_host="${TARGET}"

  export NIX_SSHOPTS="${SSH_OPTS}"

  nix run .#nixos-rebuild -- \
    switch \
    --flake ".#${NODE_NAME}" \
    --target-host "${ssh_target}" \
    --build-host "${ssh_build_host}" \
    --fast \
    --install-bootloader
}

should_install_bootloader() {
  case "${BOOTSTRAP_INSTALL_BOOTLOADER}" in
    1|true|yes)
      return 0
      ;;
    0|false|no)
      return 1
      ;;
    auto)
      [ "${DEPLOY_USER}" = "root" ]
      ;;
    *)
      die "Invalid BOOTSTRAP_INSTALL_BOOTLOADER value: ${BOOTSTRAP_INSTALL_BOOTLOADER}"
      ;;
  esac
}

resolve_age_key_source
prepare_remote_time
push_age_key_to_target

if should_install_bootloader; then
  echo "Running bootstrap deploy with nixos-rebuild --install-bootloader on ${TARGET} ..."
  run_bootstrap_switch
else
  run_colmena
fi
