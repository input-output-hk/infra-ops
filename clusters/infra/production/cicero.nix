{ pkgs, ... }: {
  services = {
    postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql_13;

      authentication = ''
        local all all trust
        host all all 10.0.0.0/8 trust
      '';

      initialScript = pkgs.writeText "init.sql" ''
        CREATE DATABASE cicero;
        CREATE USER cicero;
        GRANT ALL PRIVILEGES ON DATABASE cicero to cicero;
        ALTER USER cicero WITH SUPERUSER;

        CREATE ROLE cicero_api;
      '';
    };
  };
}
