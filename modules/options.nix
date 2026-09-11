{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.edgeCluster = {
    stateDir = mkOption {
      type = types.str;
      default = "/srv/edge-cluster";
      description = "Base directory for host-managed state used by cluster workloads.";
    };

    bootstrap = {
      enable = mkEnableOption "temporary bootstrap mode for first deploy and reboot validation";

      permitRootLogin = mkOption {
        type = types.bool;
        default = true;
        description = "Allow root SSH during bootstrap using prohibit-password semantics.";
      };
    };

    sops = {
      ageKeyFile = mkOption {
        type = types.str;
        default = "/var/lib/sops-nix/key.txt";
        description = "Stable age key path staged before deployment.";
      };

      defaultSopsFile = mkOption {
        type = types.path;
        description = "Default encrypted SOPS file for this cluster.";
      };
    };

    apps.rustdesk = {
      enable = mkEnableOption "RustDesk server on K3s";

      namespace = mkOption {
        type = types.str;
        default = "rustdesk";
      };

      serverHost = mkOption {
        type = types.str;
        default = "cloud-edge-1";
        description = "Tailscale MagicDNS name or tailnet FQDN clients should use.";
      };

      image = mkOption {
        type = types.str;
        default = "rustdesk/rustdesk-server:latest";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/srv/edge-cluster/rustdesk";
      };

      enableWebClient = mkOption {
        type = types.bool;
        default = false;
      };

      ports = {
        natTest = mkOption {
          type = types.port;
          default = 21115;
        };

        signal = mkOption {
          type = types.port;
          default = 21116;
        };

        relay = mkOption {
          type = types.port;
          default = 21117;
        };

        wsSignal = mkOption {
          type = types.port;
          default = 21118;
        };

        wsRelay = mkOption {
          type = types.port;
          default = 21119;
        };
      };
    };

    apps.searxng = {
      enable = mkEnableOption "private SearXNG instance on K3s";

      image = mkOption {
        type = types.str;
        default = "docker.io/searxng/searxng:2026.9.3-745d5b6fc@sha256:3cbe78486a5e4f7c7fe22e2ba82b28d02390e7fc03b1139f5788b07d2ac0a1f8";
        description = "Digest-pinned SearXNG OCI image.";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Host address where the SearXNG pod listens.";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Host port where the SearXNG pod listens.";
      };

      httpsPort = mkOption {
        type = types.port;
        default = 443;
        description = "Tailscale Serve HTTPS port for SearXNG.";
      };

      publicUrl = mkOption {
        type = types.str;
        default = "https://cloud-edge-1.tail8f7f61.ts.net/";
        description = "Tailnet-only public URL advertised by SearXNG.";
      };
    };

    backup = {
      enable = mkEnableOption "restic backups for cluster state and workloads";

      stateDir = mkOption {
        type = types.str;
        default = "/srv/restic-backup";
      };

      paths = mkOption {
        type = types.listOf types.str;
        default = [];
      };

      repositorySecret = mkOption {
        type = types.str;
        default = "backup/restic_repository";
      };

      passwordSecret = mkOption {
        type = types.str;
        default = "backup/restic_password";
      };

      environmentSecret = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
}
