{config, ...}: {
  systemd.tmpfiles.rules = [
    "d ${config.edgeCluster.stateDir} 0750 root root -"
  ];
}
