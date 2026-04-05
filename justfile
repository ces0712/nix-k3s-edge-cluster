set shell := ["sh", "-cu"]

NODE_NAME := env_var_or_default("NODE_NAME", "cloud-edge-1")
TARGET_HOST := env_var_or_default("TARGET_HOST", env_var_or_default("TAILNET_HOST", "cloud-edge-1"))
DEPLOY_USER := env_var_or_default("DEPLOY_USER", "nixos")
IDENTITY_FILE := env_var_or_default("IDENTITY_FILE", "")
BOOTSTRAP_INSTALL_BOOTLOADER := env_var_or_default("BOOTSTRAP_INSTALL_BOOTLOADER", "auto")
KUBECONFIG_SERVER := env_var_or_default("KUBECONFIG_SERVER", TARGET_HOST)
OUTPUT_PATH := env_var_or_default("OUTPUT_PATH", env_var("HOME") + "/.kubeconfig/" + NODE_NAME + ".yaml")
SOPS_AGE_KEY_FILE := env_var_or_default("SOPS_AGE_KEY_FILE", "")
SOPS_AGE_KEY_PASS_ENTRY := env_var_or_default("SOPS_AGE_KEY_PASS_ENTRY", "sops/age-key")
ACT_RUNNER_IMAGE := env_var_or_default("ACT_RUNNER_IMAGE", "ghcr.io/catthehacker/ubuntu:act-latest")
ACT_CONTAINER_ARCH := env_var_or_default("ACT_CONTAINER_ARCH", "linux/amd64")
ACT_PODMAN_MACHINE := env_var_or_default("ACT_PODMAN_MACHINE", "podman-machine-default")

default: help

help:
  @echo "Usage:"
  @echo "  just fmt            -> format Nix files"
  @echo "  just fmt-check      -> check formatting without changes"
  @echo "  just build-eval     -> evaluate the NixOS host config"
  @echo "  just colmena-eval   -> evaluate the Colmena hive"
  @echo "  just flake-check    -> run flake checks"
  @echo "  just check          -> run all repo checks"
  @echo "  just act-dryrun-all -> dry-run all Forgejo workflows with act + Podman"
  @echo "  just deploy         -> bootstrap with nixos-rebuild when DEPLOY_USER=root, otherwise apply with Colmena"
  @echo "  just validate       -> validate the deployed node over Tailscale"
  @echo "  just export-kubeconfig -> write a local kubeconfig that points at the Tailscale host"
  @echo "  just backup-validate -> validate backup readiness when enabled"
  @echo "  just upgrade-rehearsal -> run checks and optionally deploy/validate a rehearsal target"
  @echo ""
  @echo "Variables:"
  @echo "  NODE_NAME=<name>          -> default: cloud-edge-1"
  @echo "  TARGET_HOST=<tailnet-host> -> default: cloud-edge-1"
  @echo "  TAILNET_HOST=<tailnet-host> -> alias for TARGET_HOST"
  @echo "  DEPLOY_USER=<user>        -> default: nixos"
  @echo "  IDENTITY_FILE=<path>      -> optional SSH key"
  @echo "  BOOTSTRAP_INSTALL_BOOTLOADER=<auto|true|false> -> default: auto"
  @echo "  KUBECONFIG_SERVER=<host>  -> default: TARGET_HOST"
  @echo "  OUTPUT_PATH=<path>        -> default: $HOME/.kubeconfig/<node>.yaml"
  @echo "  SOPS_AGE_KEY_FILE=<path>  -> optional path to age key file"
  @echo "  SOPS_AGE_KEY_PASS_ENTRY=<entry> -> default: sops/age-key"
  @echo "  ACT_RUNNER_IMAGE=<image>  -> default: ghcr.io/catthehacker/ubuntu:act-latest"
  @echo "  ACT_CONTAINER_ARCH=<arch> -> default: linux/amd64"
  @echo "  ACT_PODMAN_MACHINE=<name> -> default: podman-machine-default"

fmt:
  nix fmt .

fmt-check:
  nix fmt -- --check .

build-eval:
  nix eval '.#nixosConfigurations.cloud-edge-1.config.system.build.toplevel.drvPath' --raw > /dev/null

colmena-eval:
  nix eval '.#colmena.cloud-edge-1.deployment.targetHost' --raw > /dev/null

flake-check:
  nix flake check --all-systems

check: fmt-check build-eval colmena-eval flake-check

act-dryrun-all:
  socket_path="$(podman machine inspect {{ACT_PODMAN_MACHINE}} --format '{{ "{{" }}.ConnectionInfo.PodmanSocket.Path{{ "}}" }}')"; \
  export DOCKER_HOST="unix://${socket_path}"; \
  export ACT_CACHE_DIR=/tmp/act-cache; \
  act -n -W .forgejo/workflows -j checks -P self-hosted={{ACT_RUNNER_IMAGE}} --container-architecture {{ACT_CONTAINER_ARCH}}; \
  act -n -W .forgejo/workflows -j backup-validate -P self-hosted={{ACT_RUNNER_IMAGE}} --container-architecture {{ACT_CONTAINER_ARCH}}; \
  act workflow_dispatch -n -W .forgejo/workflows -j deploy -P self-hosted={{ACT_RUNNER_IMAGE}} --container-architecture {{ACT_CONTAINER_ARCH}}

deploy:
  NODE_NAME={{NODE_NAME}} TARGET_HOST={{TARGET_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} BOOTSTRAP_INSTALL_BOOTLOADER={{BOOTSTRAP_INSTALL_BOOTLOADER}} SOPS_AGE_KEY_FILE={{SOPS_AGE_KEY_FILE}} SOPS_AGE_KEY_PASS_ENTRY={{SOPS_AGE_KEY_PASS_ENTRY}} ./scripts/deploy.sh

validate:
  NODE_NAME={{NODE_NAME}} TARGET_HOST={{TARGET_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} ./scripts/validate.sh

export-kubeconfig:
  NODE_NAME={{NODE_NAME}} TARGET_HOST={{TARGET_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} KUBECONFIG_SERVER={{KUBECONFIG_SERVER}} OUTPUT_PATH={{OUTPUT_PATH}} ./scripts/export-kubeconfig.sh

backup-validate:
  NODE_NAME={{NODE_NAME}} TARGET_HOST={{TARGET_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} ./scripts/backup-validate.sh

upgrade-rehearsal:
  NODE_NAME={{NODE_NAME}} TARGET_HOST={{TARGET_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} SOPS_AGE_KEY_FILE={{SOPS_AGE_KEY_FILE}} SOPS_AGE_KEY_PASS_ENTRY={{SOPS_AGE_KEY_PASS_ENTRY}} ./scripts/upgrade-rehearsal.sh
