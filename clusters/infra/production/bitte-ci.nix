{ self, lib, config, pkgs, ... }: {
  imports = [ (self.inputs.bitte-ci + /modules/bitte-ci.nix) ];

  services = {
    # TODO: move this to appropriate location
    ingress-config.enable = lib.mkForce false;
    ingress.enable = lib.mkForce false;

    vault-agent.enable = true;
    vault-agent.role = "core";
    vault-agent.templates."/run/keys/bitte-ci.nomad" = {
      contents = ''
        {{- with secret "nomad/creds/bitte-ci" }}{{ .Data.secret_id }}{{ end -}}
      '';
      command =
        "${pkgs.systemd}/bin/systemctl restart bitte-ci-server bitte-ci-listener";
    };

    bitte-ci = {
      enable = false;
      host = config.cluster.coreNodes.hydra.privateIP;
      postgresUrl = "postgres://bitte_ci@/bitte_ci?host=/run/postgresql";
      publicUrl = "http://ci.${config.cluster.domain}";
      lokiUrl = "http://${config.cluster.coreNodes.monitoring.privateIP}:3100";
      githubUser = "iohk-devops";
      githubTokenFile = "/run/keys/bitte-ci.token";
      nomadTokenFile = "/run/keys/bitte-ci.nomad";
      artifactSecretFile = "/run/keys/bitte-ci.artifact";
      githubHookSecretFile = "/run/keys/bitte-ci.secret";
      nomadUrl = "https://nomad.${config.cluster.domain}";
      nomadSslCa = "/etc/ssl/certs/ca.pem";
      nomadSslKey = "/etc/ssl/certs/cert-key.pem";
      nomadSslCert = "/etc/ssl/certs/cert.pem";
      nomadDatacenters = [ "eu-central-1" "us-east-2" ];
    };

    postgresql = {
      enable = true;
      enableTCPIP = true;

      authentication = ''
        local all all trust
        host all all 10.0.0.0/8 trust
      '';

      initialScript = pkgs.writeText "init.sql" ''
        CREATE DATABASE bitte_ci;
        CREATE USER bitte_ci;
        GRANT ALL PRIVILEGES ON DATABASE bitte_ci to bitte_ci;
        ALTER USER bitte_ci WITH SUPERUSER;

        CREATE DATABASE cicero;
        CREATE USER cicero;
        GRANT ALL PRIVILEGES ON DATABASE cicero to cicero;
        ALTER USER cicero WITH SUPERUSER;

        CREATE ROLE cicero_api;
      '';
    };
  };

  secrets.install.bitte-ci = {
    inputType = "json";
    outputType = "json";
    source = config.secrets.encryptedRoot + "/bitte-ci.json";
    target = "/run/keys/bitte-ci.json";
    script = ''
      export PATH="${lib.makeBinPath [ pkgs.jq ]}"
      jq -e -r .token < /run/keys/bitte-ci.json > /run/keys/bitte-ci.token
      jq -e -r .secret < /run/keys/bitte-ci.json > /run/keys/bitte-ci.secret
      jq -e -r .artifact < /run/keys/bitte-ci.json > /run/keys/bitte-ci.artifact
    '';
  };
}
