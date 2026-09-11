{
  config,
  lib,
  secrets,
  ...
}: let
  cfg = config.edgeCluster.apps.searxng;
  settingsTemplate = builtins.readFile ./settings.yml;
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasInfix "@sha256:" cfg.image;
        message = "edgeCluster.apps.searxng.image must be pinned by digest";
      }
      {
        assertion = cfg.listenAddress == "127.0.0.1";
        message = "SearXNG must remain bound to 127.0.0.1 behind Tailscale Serve";
      }
    ];

    sops.secrets = {
      "searxng/brave_api_key" = {
        sopsFile = secrets + "/secrets/k3s.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "searxng/secret_key" = {
        sopsFile = secrets + "/secrets/k3s.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates."searxng-settings.yml" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content =
        builtins.replaceStrings
        [
          "@BRAVE_API_KEY@"
          "@SEARXNG_SECRET_KEY@"
        ]
        [
          config.sops.placeholder."searxng/brave_api_key"
          config.sops.placeholder."searxng/secret_key"
        ]
        settingsTemplate;
    };

    services.k3s.manifests.searxng = {
      target = "searxng.yaml";
      content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = "searxng";
            labels."app.kubernetes.io/part-of" = "edge-cluster";
          };
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "searxng";
            namespace = "searxng";
            labels = {
              "app.kubernetes.io/name" = "searxng";
              "app.kubernetes.io/part-of" = "edge-cluster";
            };
          };
          spec = {
            replicas = 1;
            strategy.type = "Recreate";
            selector.matchLabels."app.kubernetes.io/name" = "searxng";
            template = {
              metadata.labels = {
                "app.kubernetes.io/name" = "searxng";
                "app.kubernetes.io/part-of" = "edge-cluster";
              };
              metadata.annotations."edge-cluster/secrets-hash" =
                builtins.hashFile "sha256" (secrets + "/secrets/k3s.yaml");
              spec = {
                hostNetwork = true;
                dnsPolicy = "ClusterFirstWithHostNet";
                automountServiceAccountToken = false;
                terminationGracePeriodSeconds = 30;
                volumes = [
                  {
                    name = "settings";
                    hostPath = {
                      path = config.sops.templates."searxng-settings.yml".path;
                      type = "File";
                    };
                  }
                ];
                containers = [
                  {
                    name = "searxng";
                    image = cfg.image;
                    imagePullPolicy = "IfNotPresent";
                    env = [
                      {
                        name = "FORCE_OWNERSHIP";
                        value = "false";
                      }
                      {
                        name = "GRANIAN_HOST";
                        value = cfg.listenAddress;
                      }
                      {
                        name = "GRANIAN_PORT";
                        value = toString cfg.port;
                      }
                      {
                        name = "SEARXNG_BASE_URL";
                        value = cfg.publicUrl;
                      }
                    ];
                    ports = [
                      {
                        name = "http";
                        containerPort = cfg.port;
                        protocol = "TCP";
                      }
                    ];
                    securityContext = {
                      allowPrivilegeEscalation = false;
                      capabilities.drop = ["ALL"];
                      seccompProfile.type = "RuntimeDefault";
                    };
                    resources = {
                      requests = {
                        cpu = "100m";
                        memory = "256Mi";
                      };
                      limits = {
                        cpu = "500m";
                        memory = "512Mi";
                      };
                    };
                    startupProbe = {
                      httpGet = {
                        host = cfg.listenAddress;
                        path = "/healthz";
                        port = "http";
                      };
                      periodSeconds = 2;
                      failureThreshold = 60;
                    };
                    readinessProbe = {
                      httpGet = {
                        host = cfg.listenAddress;
                        path = "/healthz";
                        port = "http";
                      };
                      periodSeconds = 5;
                      failureThreshold = 3;
                    };
                    livenessProbe = {
                      httpGet = {
                        host = cfg.listenAddress;
                        path = "/healthz";
                        port = "http";
                      };
                      periodSeconds = 10;
                      failureThreshold = 3;
                    };
                    volumeMounts = [
                      {
                        name = "settings";
                        mountPath = "/etc/searxng/settings.yml";
                        readOnly = true;
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
  };
}
