{
  config,
  secrets,
  ...
}: {
  edgeCluster.sops.defaultSopsFile = secrets + "/secrets/forgejo.yaml";

  sops = {
    age = {
      keyFile = config.edgeCluster.sops.ageKeyFile;
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      generateKey = false;
    };
    defaultSopsFile = config.edgeCluster.sops.defaultSopsFile;
  };

  sops.secrets."tailscale/auth_key" = {
    owner = "root";
    group = "root";
  };
}
