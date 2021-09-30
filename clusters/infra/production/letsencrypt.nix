{ config, nodeName, lib, pkgs, ... }: {

  services.grafana.extraOptions.AUTH_PROXY_HEADER_NAME =
    lib.mkForce "X-Auth-Request-Email";

  security.acme = {
    acceptTerms = true;
    certs.routing = lib.mkIf (nodeName == "routing") {
      dnsProvider = "route53";
      dnsResolver = "1.1.1.1:53";
      email = "devops@iohk.io";
      domain = config.cluster.domain;
      credentialsFile = builtins.toFile "nothing" "";
      extraDomainNames = [ "*.${config.cluster.domain}" ]
        ++ config.cluster.extraAcmeSANs;
      postRun = ''
        cp fullchain.pem /etc/ssl/certs/${config.cluster.domain}-full.pem
        cp key.pem /etc/ssl/certs/${config.cluster.domain}-key.pem
        systemctl try-restart --no-block copy-acme-certs.service

        export VAULT_TOKEN="$(< /run/keys/vault-token)"
        vault kv put kv/bootstrap/letsencrypt/key value=@key.pem
        vault kv put kv/bootstrap/letsencrypt/fullchain value=@fullchain.pem
        vault kv put kv/bootstrap/letsencrypt/cert value=@cert.pem
      '';
    };
  };

  services.vault-agent = lib.mkIf (nodeName == "monitoring") {
    templates = let
      command =
        "${pkgs.systemd}/bin/systemctl try-restart --no-block ingress.service";
    in {
      "/etc/ssl/certs/${config.cluster.domain}-cert.pem" = {
        contents = ''
          {{ with secret "kv/bootstrap/letsencrypt/cert" }}{{ .Data.data.value }}{{ end }}
        '';
        inherit command;
      };

      "/etc/ssl/certs/${config.cluster.domain}-full.pem" = {
        contents = ''
          {{ with secret "kv/bootstrap/letsencrypt/fullchain" }}{{ .Data.data.value }}{{ end }}
        '';
        inherit command;
      };

      "/etc/ssl/certs/${config.cluster.domain}-key.pem" = {
        contents = ''
          {{ with secret "kv/bootstrap/letsencrypt/key" }}{{ .Data.data.value }}{{ end }}
        '';
        inherit command;
      };

      "/etc/ssl/certs/${config.cluster.domain}-full.pem.key" = {
        contents = ''
          {{ with secret "kv/bootstrap/letsencrypt/key" }}{{ .Data.data.value }}{{ end }}
        '';
        inherit command;
      };
    };
  };
}
