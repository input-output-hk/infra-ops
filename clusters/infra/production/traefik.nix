{ self, lib, pkgs, config, ... }:
let inherit (config.cluster) domain;
in {
  services.consul.ui = true;

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
              authResponseHeaders = [
                "X-Auth-Request-User"
                "X-Auth-Request-Email"
                "X-Auth-Request-Access-Token"
                "Authorization"
              ];
              trustForwardHeader = true;
            };
          };
        };

        routers = let
          mkOauthRoute = service: {
            inherit service;
            entrypoints = "https";
            middlewares = [ "oauth-auth-redirect" ];
            rule = "Host(`${service}.${domain}`) && PathPrefix(`/`)";
            tls = true;
          };
        in lib.mkForce {
          oauth2-route = {
            entrypoints = "https";
            middlewares = [ "auth-headers" ];
            rule = "PathPrefix(`/oauth2/`)";
            service = "oauth-backend";
            priority = 999;
            tls = true;
          };

          oauth2-proxy-route = {
            entrypoints = "https";
            middlewares = [ "auth-headers" ];
            rule = "Host(`oauth.${domain}`) && PathPrefix(`/`)";
            service = "oauth-backend";
            tls = true;
          };

          grafana = mkOauthRoute "monitoring";
          nomad = mkOauthRoute "nomad";

          nomad-api = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`nomad.${domain}`) && PathPrefix(`/v1/`)";
            service = "nomad";
            tls = true;
          };

          vault = mkOauthRoute "vault";

          vault-api = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`vault.${domain}`) && PathPrefix(`/v1/`)";
            service = "vault";
            tls = true;
          };

          consul = mkOauthRoute "consul";

          consul-api = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`consul.${domain}`) && PathPrefix(`/v1/`)";
            service = "consul";
            tls = true;
          };

          traefik = {
            entrypoints = "https";
            middlewares = [ "oauth-auth-redirect" ];
            rule = "Host(`traefik.${domain}`) && PathPrefix(`/`)";
            service = "api@internal";
            tls = true;
          };

          vault-backend = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`vbk.${domain}`) && PathPrefix(`/`)";
            service = "vault-backend";
            tls = true;
          };

          docker-registry = {
            entrypoints = "https";
            middlewares = [ ];
            rule = "Host(`docker.${domain}`) && PathPrefix(`/`)";
            service = "docker-registry";
            tls = true;
          };
        };

        services = {
          docker-registry.loadBalancer = {
            servers = [{ url = "http://monitoring:5000"; }];
          };

          vault-backend.loadBalancer = {
            servers = [{ url = "http://monitoring:8080"; }];
          };

          oauth-backend.loadBalancer = {
            servers = [{ url = "http://127.0.0.1:4180"; }];
          };

          consul.loadBalancer = {
            servers = [{ url = "http://127.0.0.1:8500"; }];
          };

          nomad.loadBalancer = {
            servers = [{ url = "https://nomad.service.consul:4646"; }];
            serversTransport = "cert-transport";
          };

          monitoring.loadBalancer = {
            servers = [{ url = "http://monitoring:3000"; }];
          };

          vault.loadBalancer = {
            servers = [{ url = "https://active.vault.service.consul:8200"; }];
            serversTransport = "cert-transport";
          };
        };

        serversTransports = {
          cert-transport = {
            insecureSkipVerify = true;
            rootCAs = [ "/etc/ssl/certs/full.pem" ];
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

  /* services.oauth2_proxy.provider = lib.mkForce "github";
     services.oauth2_proxy.keyFile = lib.mkForce "/run/keys/github-oauth-secrets";
     services.oauth2_proxy.extraConfig.skip-provider-button = "true";
     services.oauth2_proxy.extraConfig.upstream = "static://202";
     services.oauth2_proxy.extraConfig.github-user =
       builtins.concatStringsSep "," [ "manveru" "dermetfan" "biandratti" ];
     services.oauth2_proxy.extraConfig.github-org = "input-output-hk";
     services.oauth2_proxy.email.domains = lib.mkForce [ "*" ];
     services.oauth2_proxy.scope = builtins.concatStringsSep "," [
       "user:email"
       "read:public_key"
       "read:org"
       "repo"
     ];
     # services.oauth2_proxy.extraConfig.set-authorization-header=true;
     services.oauth2_proxy.extraConfig.pass-access-token = true;

     secrets.install.github-oauth.script = ''
       export PATH="${lib.makeBinPath (with pkgs; [ sops coreutils ])}"
       dest=/run/keys/github-oauth-secrets
       sops -d ${config.secrets.encryptedRoot + /github-oauth-secrets} > "$dest"
       chown root:keys "$dest"
       chmod g+r "$dest"
     '';
  */

  systemd.services.oauth2_proxy.serviceConfig.RestartSec = "5s";
}
