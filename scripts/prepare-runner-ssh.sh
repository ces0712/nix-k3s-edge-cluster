#!/bin/sh
set -eu

install -m 700 -d "${HOME}/.ssh"

SECRETS_REPO_IDENTITY_FILE="${SECRETS_REPO_IDENTITY_FILE:-${HOME}/.ssh/id_ed25519_github}"
EDGE_IDENTITY_FILE="${EDGE_IDENTITY_FILE:-${HOME}/.ssh/edge-cluster}"
RUNNER_TEMP_DIR="${RUNNER_TEMP:-/tmp}"
SSH_CONFIG_FILE="$(mktemp "${RUNNER_TEMP_DIR}/edge-cluster-git-ssh.XXXXXX")"

[ -f "${SECRETS_REPO_IDENTITY_FILE}" ] || {
  echo "Missing secrets repo SSH identity: ${SECRETS_REPO_IDENTITY_FILE}" >&2
  exit 1
}

chmod 600 "${SECRETS_REPO_IDENTITY_FILE}"

if [ -f "${EDGE_IDENTITY_FILE}" ]; then
  chmod 600 "${EDGE_IDENTITY_FILE}"
fi

cat > "${SSH_CONFIG_FILE}" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${SECRETS_REPO_IDENTITY_FILE}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    printf 'SECRETS_REPO_IDENTITY_FILE=%s\n' "${SECRETS_REPO_IDENTITY_FILE}"
    printf 'EDGE_IDENTITY_FILE=%s\n' "${EDGE_IDENTITY_FILE}"
    printf 'RUNNER_GIT_SSH_CONFIG=%s\n' "${SSH_CONFIG_FILE}"
    printf 'GIT_SSH_COMMAND=ssh -F %s\n' "${SSH_CONFIG_FILE}"
  } >> "${GITHUB_ENV}"
fi
