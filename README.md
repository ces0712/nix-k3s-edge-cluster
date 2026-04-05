# Private NixOS K3s Edge Cluster

Declarative infrastructure for a private, Tailscale-only K3s cluster on NixOS.
The first workload is RustDesk, but the repository is structured as a platform so
we can keep adding services without reshaping the core.

## Goals

- Reuse the working patterns from `infrastructure-nixos`
- Reuse the same `infrastructure-secrets` repo with `sops-nix`
- Keep all inbound access private over Tailscale
- Use Colmena from day one for reproducible deployments
- Make validation and recovery checks runnable both locally and in CI

## Architecture

- `hosts/` contains environment-specific host definitions
- `modules/` contains reusable NixOS platform modules
- `apps/` contains app-specific NixOS modules and K3s manifests
- `scripts/` contains thin operator and CI wrappers
- `.forgejo/workflows/` contains CI/CD pipelines for checks, deploys, and backup validation

Current topology:

- Oracle Cloud host running NixOS + K3s
- RustDesk deployed through `services.k3s.manifests`
- Tailscale is the steady-state access plane for SSH, K3s API, and RustDesk ports
- Bootstrap mode temporarily opens public SSH on port `22` until the first reboot and Tailscale validation succeed
- After bootstrap is disabled, root SSH is turned off and OCI should close public SSH ingress; the host firewall keeps `22` available so OCI can provide a break-glass path if needed

## Repository Layout

```text
.
├── apps/
│   └── rustdesk/
├── hosts/
│   └── cloud-edge-1/
├── modules/
├── scripts/
├── .forgejo/workflows/
├── flake.nix
└── justfile
```

## Secrets

This repo intentionally reuses the same secrets repository used by
`infrastructure-nixos`:

- flake input: `git+ssh://git@github.com/ces0712/infrastructure-secrets.git`
- default SOPS file: `secrets/forgejo.yaml` from that repository
- reused key today: `tailscale.auth_key`

That lets us keep the same deploy-time age key staging pattern and the same
`sops-nix` mental model you already trust.

If we later enable backup to OCI Object Storage, add a dedicated encrypted file
such as `secrets/edge-cluster.yaml` in `infrastructure-secrets` and point
`edgeCluster.sops.defaultSopsFile` at it.

## Oracle Notes

This repo is opinionated toward a single Oracle Cloud `VM.Standard.A1.Flex`
instance for v1.

Recommended starting point:

- 1 OCPU / 6 GB RAM minimum for a rehearsal box
- 2 OCPUs / 12 GB RAM if you want more room for demos
- no public inbound security-list rules
- Tailscale on the host before using Colmena

The default host config assumes an existing NixOS host reachable over Tailscale.
Before the first real deploy, review `hosts/cloud-edge-1/default.nix` and adjust
the root filesystem device and EFI partition if your Oracle image uses a
different layout.

For the current Oracle ARM image flow, the repo expects:

- root filesystem label: `cloudimg-rootfs`
- EFI partition label: `UEFI`
- `systemd-boot` on `/boot/efi`

## Local Workflow

Prerequisites:

- Nix with flakes enabled
- access to `git@github.com:ces0712/infrastructure-secrets.git`
- Tailscale access to the target host

Common commands:

```bash
just fmt-check
just build-eval
just colmena-eval
TARGET_HOST=cloud-edge-1.tailnet.ts.net just deploy
TARGET_HOST=cloud-edge-1.tailnet.ts.net just validate
TARGET_HOST=cloud-edge-1.tailnet.ts.net just backup-validate
TARGET_HOST=cloud-edge-1.tailnet.ts.net just export-kubeconfig
```

Bootstrap sequence:

```bash
# bootstrap enabled in hosts/cloud-edge-1/default.nix
# root bootstrap deploy automatically uses the flake-pinned nixos-rebuild
# and runs switch --install-bootloader
TARGET_HOST=<public-ip> DEPLOY_USER=root IDENTITY_FILE=$HOME/.ssh/oracle-bootstrap just deploy
TARGET_HOST=<public-ip> DEPLOY_USER=root IDENTITY_FILE=$HOME/.ssh/oracle-bootstrap just validate

# reboot while bootstrap mode is still enabled and verify SSH + Tailscale

# then disable edgeCluster.bootstrap.enable and close OCI bootstrap access
TARGET_HOST=cloud-edge-1.tailnet.ts.net just deploy
TARGET_HOST=cloud-edge-1.tailnet.ts.net just validate
```

To use `kubectl` or `k9s` from your Mac, export a kubeconfig that points to the
Tailscale host:

```bash
TARGET_HOST=cloud-edge-1.tailnet.ts.net DEPLOY_USER=nixos IDENTITY_FILE=<admin-private-key> just export-kubeconfig
KUBECONFIG=$HOME/.kubeconfig/cloud-edge-1.yaml kubectl get nodes
KUBECONFIG=$HOME/.kubeconfig/cloud-edge-1.yaml k9s
```

## CI / Runner Notes

The Mac mini runner should be on Tailscale before deploy automation is enabled.
CI is designed to:

- run formatting and eval checks on pull requests and main
- deploy manually or on protected branches through the runner's existing Tailscale connection
- run post-deploy validation automatically
- optionally run scheduled backup validation if backups are enabled

The workflows assume the runner owns the SSH identities locally instead of
reconstructing private keys from CI secrets:

- `SECRETS_REPO_IDENTITY_FILE` points to the runner-local key used to fetch
  `infrastructure-secrets`
- `EDGE_IDENTITY_FILE` points to the runner-local key used by Colmena to reach
  the target over Tailscale
- if those variables are not set, the workflows default to
  `~/.ssh/infrastructure-secrets` and `~/.ssh/edge-cluster`

That keeps the Mac mini as the trust anchor and leaves the workflow responsible
for invoking the deploy scripts over the runner's existing tailnet access. The helper script
exports an ephemeral `GIT_SSH_COMMAND` for the private flake input instead of
rewriting the runner's global SSH config. Colmena still uses SSH as its
transport, but only to the Tailscale/MagicDNS target you provide.

## Upgrade Strategy

- Pin dependencies in `flake.lock` and commit the lock file
- Rehearse updates in a branch first
- Run `just check`
- Deploy over Tailscale with Colmena
- Run `just validate`
- Promote only after the rehearsal node is healthy

Rollback strategy:

- host rollback through NixOS generations
- workload rollback through Git history and redeploy

## Binary Cache Recommendation

Start with `cache.nixos.org` and build on the target host.

When repeated CI/deploy builds become slow enough to hurt, add Cachix before
considering a self-hosted cache. That keeps the first iteration focused on the
cluster and not on operating extra infrastructure.
