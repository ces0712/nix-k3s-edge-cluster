{
  description = "Deterministic K3s Edge Cluster on NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    # NixOS configurations and Colmena outputs will be defined here
  };
}
