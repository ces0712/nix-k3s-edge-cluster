{lib, ...}: {
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
      "--write-kubeconfig-mode=0640"
    ];
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkAfter [6443];
}
