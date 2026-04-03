{
  config,
  lib,
  ...
}: let
  cfg = config.edgeCluster.apps.rustdesk;
  tcpPorts =
    [
      cfg.ports.natTest
      cfg.ports.signal
      cfg.ports.relay
    ]
    ++ lib.optionals cfg.enableWebClient [
      cfg.ports.wsSignal
      cfg.ports.wsRelay
    ];
  udpPorts = [cfg.ports.signal];
in
  lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ];

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = lib.mkAfter tcpPorts;
      allowedUDPPorts = lib.mkAfter udpPorts;
    };

    services.k3s.manifests.rustdesk = {
      target = "rustdesk.yaml";
      content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = cfg.namespace;
          };
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "rustdesk-server";
            namespace = cfg.namespace;
            labels = {
              "app.kubernetes.io/name" = "rustdesk";
              "app.kubernetes.io/part-of" = "edge-cluster";
            };
          };
          spec = {
            replicas = 1;
            selector.matchLabels = {
              "app.kubernetes.io/name" = "rustdesk";
            };
            template = {
              metadata.labels = {
                "app.kubernetes.io/name" = "rustdesk";
                "app.kubernetes.io/part-of" = "edge-cluster";
              };
              spec = {
                hostNetwork = true;
                dnsPolicy = "ClusterFirstWithHostNet";
                restartPolicy = "Always";
                volumes = [
                  {
                    name = "rustdesk-data";
                    hostPath = {
                      path = cfg.dataDir;
                      type = "DirectoryOrCreate";
                    };
                  }
                ];
                containers = [
                  {
                    name = "hbbs";
                    image = cfg.image;
                    args = [
                      "hbbs"
                      "-r"
                      "${cfg.serverHost}:${toString cfg.ports.relay}"
                    ];
                    ports =
                      [
                        {
                          name = "nat-test";
                          containerPort = cfg.ports.natTest;
                          protocol = "TCP";
                        }
                        {
                          name = "signal-tcp";
                          containerPort = cfg.ports.signal;
                          protocol = "TCP";
                        }
                        {
                          name = "signal-udp";
                          containerPort = cfg.ports.signal;
                          protocol = "UDP";
                        }
                      ]
                      ++ lib.optionals cfg.enableWebClient [
                        {
                          name = "ws-signal";
                          containerPort = cfg.ports.wsSignal;
                          protocol = "TCP";
                        }
                      ];
                    volumeMounts = [
                      {
                        name = "rustdesk-data";
                        mountPath = "/root";
                      }
                    ];
                  }
                  {
                    name = "hbbr";
                    image = cfg.image;
                    args = ["hbbr"];
                    ports =
                      [
                        {
                          name = "relay";
                          containerPort = cfg.ports.relay;
                          protocol = "TCP";
                        }
                      ]
                      ++ lib.optionals cfg.enableWebClient [
                        {
                          name = "ws-relay";
                          containerPort = cfg.ports.wsRelay;
                          protocol = "TCP";
                        }
                      ];
                    volumeMounts = [
                      {
                        name = "rustdesk-data";
                        mountPath = "/root";
                      }
                    ];
                  }
                ];
              };
            };
          };
        }
      ];
    };
  }
