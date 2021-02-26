{ lib, config, pkgs, ... }:
let cfg = config.services.vault-backend;
in {
  options = {
    services.vault-backend = {
      enable = lib.mkEnableOption "Enable the Terraform Vault Backend";
    };
  };

  config = {
    systemd.services.vault-backend = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.vault-backend}/bin/vault-backend";
        Restart = "on-failure";
        RestartSec = "10s";
        DynamicUser = true;
        PrivateTmp = true;
      };
    };
  };
}
