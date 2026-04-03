let
  envOr = name: fallback:
    let
      value = builtins.getEnv name;
    in
      if value == "" then fallback else value;
in {
  imports = [./default.nix];

  deployment = {
    targetHost = envOr "TARGET_HOST" "cloud-edge-1";
    targetUser = envOr "DEPLOY_USER" "nixos";
    buildOnTarget = true;
    tags = [
      "edge"
      "k3s"
      "oracle"
      "private"
    ];
  };
}
