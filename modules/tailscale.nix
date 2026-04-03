{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = false;
    authKeyFile = config.sops.secrets."tailscale/auth_key".path;
    extraUpFlags = [
      "--accept-dns=true"
      "--hostname=${config.networking.hostName}"
    ];
  };

  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    interfaces.tailscale0.allowedTCPPorts = [22];
  };
}
