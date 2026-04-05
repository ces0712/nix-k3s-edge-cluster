{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.edgeCluster.backup;
  environmentFile = lib.optionalAttrs (cfg.environmentSecret != null) {
    environmentFile = config.sops.secrets.${cfg.environmentSecret}.path;
  };
in
  lib.mkIf cfg.enable {
    users.users.restic-backup = {
      isSystemUser = true;
      group = "restic-backup";
      home = "${config.edgeCluster.stateDir}/restic";
      createHome = true;
    };

    users.groups.restic-backup = {};

    systemd.tmpfiles.rules = [
      "d ${config.edgeCluster.stateDir}/restic 0750 restic-backup restic-backup -"
    ];

    sops.secrets =
      {
        ${cfg.repositorySecret} = {
          owner = "restic-backup";
          group = "restic-backup";
        };

        ${cfg.passwordSecret} = {
          owner = "restic-backup";
          group = "restic-backup";
        };
      }
      // lib.optionalAttrs (cfg.environmentSecret != null) {
        ${cfg.environmentSecret} = {
          owner = "restic-backup";
          group = "restic-backup";
          mode = "0600";
        };
      };

    services.restic.backups.edge-cluster =
      {
        initialize = true;
        repositoryFile = config.sops.secrets.${cfg.repositorySecret}.path;
        passwordFile = config.sops.secrets.${cfg.passwordSecret}.path;
        paths = cfg.paths;
        pruneOpts = [];
        runCheck = true;
        extraOptions = ["--verbose"];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      }
      // environmentFile;

    environment.systemPackages = with pkgs; [
      restic
    ];
  }
