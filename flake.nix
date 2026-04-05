{
  description = "Private Tailscale-only K3s platform on NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "git+ssh://git@github.com/ces0712/infrastructure-secrets.git";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    alejandra,
    colmena,
    nixpkgs,
    secrets,
    sops-nix,
    ...
  }: let
    lib = nixpkgs.lib;
    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    forAllSystems = lib.genAttrs supportedSystems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
      };

    specialArgs = {
      inherit inputs secrets;
    };

    baseModules = [
      sops-nix.nixosModules.sops
      ./modules/options.nix
      ./modules/common-base.nix
      ./modules/sops.nix
      ./modules/tailscale.nix
      ./modules/storage.nix
      ./modules/k3s-server.nix
      ./modules/backup.nix
      ./apps
    ];

    mkHost = {
      system,
      modules,
    }:
      lib.nixosSystem {
        inherit system specialArgs;
        modules = baseModules ++ modules;
      };

    cloudEdge1System = "aarch64-linux";
  in {
    formatter = forAllSystems (system: alejandra.packages.${system}.default);

    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          age
          jq
          just
          sops
        ];
      };
    });

    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      inherit (colmena.packages.${system}) colmena;
      inherit (pkgs) nixos-rebuild;
    });

    nixosConfigurations.cloud-edge-1 = mkHost {
      system = cloudEdge1System;
      modules = [./hosts/cloud-edge-1/default.nix];
    };

    colmena = {
      meta = {
        nixpkgs = pkgsFor cloudEdge1System;
        specialArgs = specialArgs;
      };

      defaults = {...}: {
        imports = baseModules;
      };

      cloud-edge-1 = import ./hosts/cloud-edge-1/deployment.nix;
    };

    colmenaHive = colmena.lib.makeHive self.outputs.colmena;

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
      rustdeskEnabled = self.nixosConfigurations.cloud-edge-1.config.edgeCluster.apps.rustdesk.enable;
      rustdeskHost = self.nixosConfigurations.cloud-edge-1.config.edgeCluster.apps.rustdesk.serverHost;
      manifestTargets = builtins.attrNames self.nixosConfigurations.cloud-edge-1.config.services.k3s.manifests;
    in {
      flake-eval = pkgs.writeText "flake-eval.json" (builtins.toJSON {
        hostName = self.nixosConfigurations.cloud-edge-1.config.networking.hostName;
        inherit rustdeskEnabled rustdeskHost;
      });

      k3s-manifests = pkgs.writeText "k3s-manifests.json" (builtins.toJSON manifestTargets);

      colmena-nodes = pkgs.writeText "colmena-nodes.json" (builtins.toJSON (builtins.attrNames self.colmena));
    });
  };
}
