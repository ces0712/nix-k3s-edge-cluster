{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.edgeCluster.backup;
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

    sops.secrets.${cfg.repositorySecret} = {
      owner = "restic-backup";
      group = "restic-backup";
    };

    sops.secrets.${cfg.passwordSecret} = {
      owner = "restic-backup";
      group = "restic-backup";
    };

    sops.secrets.${cfg.environmentSecret} = {
      owner = "restic-backup";
      group = "restic-backup";
      mode = "0600";
    };

    services.restic.backups.edge-cluster = {
      initialize = true;
      repositoryFile = config.sops.secrets.${cfg.repositorySecret}.path;
      passwordFile = config.sops.secrets.${cfg.passwordSecret}.path;
      environmentFile = config.sops.secrets.${cfg.environmentSecret}.path;
      paths = cfg.paths;
      pruneOpts = [];
      runCheck = true;
      extraOptions = ["--verbose"];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    environment.systemPackages = with pkgs; [
      restic
    ];
  }
