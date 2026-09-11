{
  config,
  lib,
  ...
}: let
  searxng = config.edgeCluster.apps.searxng;
  tailscale = config.services.tailscale.package;
in {
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
    interfaces.tailscale0.allowedTCPPorts =
      [22]
      ++ lib.optionals searxng.enable [searxng.httpsPort];
  };

  systemd.services.tailscale-searxng-serve = lib.mkIf searxng.enable {
    description = "Expose SearXNG through Tailscale Serve";
    wantedBy = ["multi-user.target"];
    wants = [
      "network-online.target"
      "k3s.service"
    ];
    requires = ["tailscaled.service"];
    after = [
      "network-online.target"
      "tailscaled.service"
      "k3s.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
      ExecStart = "${tailscale}/bin/tailscale serve --yes --bg --https=${toString searxng.httpsPort} http://${searxng.listenAddress}:${toString searxng.port}";
      ExecStop = "${tailscale}/bin/tailscale serve --yes --https=${toString searxng.httpsPort} off";
    };
  };
}
