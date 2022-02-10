{ self, lib, config, pkgs, ... }: {
  imports = [ (self.inputs.bitte-ci + /modules/bitte-ci.nix) ];

  services = {
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
