{
  config,
  lib,
  pkgs,
  secrets,
  ...
}: let
  bootstrapCfg = config.edgeCluster.bootstrap;
in {
  environment.etc."edge-cluster-profile".text = "runtime";

  time.timeZone = "America/Montevideo";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = true;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      (builtins.readFile "${secrets}/ssh-hosts/admin.pub")
    ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin =
        if bootstrapCfg.enable && bootstrapCfg.permitRootLogin
        then "prohibit-password"
        else "no";
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = "no";
      LogLevel = "VERBOSE";
    };
  };

  # Keep SSH open on the host firewall and let OCI NSG rules control public
  # exposure. This preserves an infra-only break-glass path if Tailscale is
  # unavailable.
  networking.firewall.allowedTCPPorts = [22];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "nixos"
      ];
      allowed-users = [
        "root"
        "nixos"
      ];
    };
  };

  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=500M
    SystemKeepFree=1G
  '';

  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    just
    k3s
    kubectl
    sqlite
    tailscale
    tmux
    vim
  ];
}
