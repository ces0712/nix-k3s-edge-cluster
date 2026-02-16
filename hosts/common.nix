{ pkgs, ... }: {
  # Base OS configuration for all nodes
  time.timeZone = "America/Montevideo";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.openssh.enable = true;
}
