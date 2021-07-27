{ self, lib, pkgs, config, ... }:
let domain = config.cluster.domain;
in {
  services.traefik = {
    enable = true;

    dynamicConfigOptions = {
      http = {
        middlewares = {
          auth-headers = {
            headers = {
              browserXssFilter = true;
              contentTypeNosniff = true;
              forceSTSHeader = true;
              frameDeny = true;
              sslHost = domain;
              sslRedirect = true;
              stsIncludeSubdomains = true;
              stsPreload = true;
              stsSeconds = 315360000;
            };
          };

          oauth-auth-redirect = {
            forwardAuth = {
              address = "https://oauth.${domain}/";
              authResponseHeaders =
                [ "X-Auth-Request-Access-Token" "Authorization" ];
              trustForwardHeader = true;
            };
          };
        };

        routers = lib.mkForce {
          hydra = {
            entrypoints = "https";
            middlewares = [ "oauth-auth-redirect" ];
            rule = "Host(`hydra.${domain}`) && PathPrefix(`/`)";
            service = "hydra";
            tls = true;
          };

          bitte-ci = {
            entrypoints = "https";
            middlewares = [ "oauth-auth-redirect" ];
            rule = "Host(`ci.${domain}`) && PathPrefix(`/`)";
            service = "bitte-ci";
            tls = true;
          };

          bitte-ci-hook = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`ci.${domain}`) && PathPrefix(`/api/v1/github`)";
            service = "bitte-ci";
            tls = true;
          };

          bitte-ci-oauth2-route = {
            entrypoints = "https";
            middlewares = [ "auth-headers" ];
            rule = "Host(`ci.${domain}`) && PathPrefix(`/oauth2/`)";
            service = "oauth-backend";
            tls = true;
          };

          traefik = {
            entrypoints = "https";
            middlewares = [ "oauth-auth-redirect" ];
            rule = "Host(`traefik.${domain}`) && PathPrefix(`/`)";
            service = "api@internal";
            tls = true;
          };

          oauth2-proxy-route = {
            entrypoints = "https";
            middlewares = [ "auth-headers" ];
            rule = "Host(`oauth.${domain}`) && PathPrefix(`/`)";
            service = "oauth-backend";
            tls = true;
          };

          services-oauth2-route = {
            entrypoints = "https";
            middlewares = [ "auth-headers" ];
            rule = "Host(`traefik.${domain}`) && PathPrefix(`/oauth2/`)";
            service = "oauth-backend";
            tls = true;
          };
        };

        services = {
          oauth-backend = {
            loadBalancer = { servers = [{ url = "http://127.0.0.1:4180"; }]; };
          };
          hydra = {
            loadBalancer = { servers = [{ url = "http://${config.cluster.instances.hydra.privateIP}:3001"; }]; };
          };
          bitte-ci = {
            loadBalancer = { servers = [{ url = "http://${config.cluster.instances.hydra.privateIP}:9494"; }]; };
          };
        };
      };
    };

    staticConfigOptions = {
      accesslog = true;
      log.level = "info";

      api = { dashboard = true; };

      entryPoints = {
        http = {
          address = ":80";
          forwardedHeaders.insecure = true;
          http = {
            redirections = {
              entryPoint = {
                scheme = "https";
                to = "https";
              };
            };
          };
        };

        https = {
          address = ":443";
          forwardedHeaders.insecure = true;
        };
      };
    };
  };

  systemd.services.copy-acme-certs = {
    before = [ "traefik.service" ];
    wantedBy = [ "traefik.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = lib.mkForce true;
      Restart = "on-failure";
      RestartSec = "30s";
    };

    path = [ pkgs.coreutils ];

    script = ''
      set -exuo pipefail

      mkdir -p /var/lib/traefik/certs
      cp /etc/ssl/certs/${config.cluster.domain}-*.pem /var/lib/traefik/certs
      chown -R traefik:traefik /var/lib/traefik
    '';
  };

  services.oauth2_proxy.extraConfig.skip-provider-button = "true";
  services.oauth2_proxy.extraConfig.upstream = "static://202";

}
