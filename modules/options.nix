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

    backup = {
      enable = mkEnableOption "restic backups for cluster state and workloads";

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
        type = types.str;
        default = "backup/restic_environment";
      };
    };
  };
}
