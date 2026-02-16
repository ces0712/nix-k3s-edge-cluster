{ ... }: {
  imports = [
    ../common.nix
    ../../modules/k3s-server.nix
    ../../modules/network.nix
  ];
  # Specific Master settings (Static IP, Hostname, etc)
  networking.hostName = "rpi-master";
}
