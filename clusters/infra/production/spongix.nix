{ inputs, config, pkgs, lib, ... }: {
  imports = [ inputs.spongix.nixosModules.spongix ];

  # systemd.tmpfiles.rules = [ "d /mnt/gv0/spongix 1777 root root -" ];

  services.spongix = {
    enable = true;
    cacheDir = "/var/lib/spongix";
    cacheSize = 400;
    host = "";
    port = 7745;
    gcInterval = "1h";
    secretKeyFiles.infra-production =
      config.secrets.install.nix-secret-key.target;
    substituters = [ "https://cache.nixos.org" "https://hydra.iohk.io" ];
    trustedPublicKeys = [
      (lib.fileContents (config.secrets.encryptedRoot + "/nix-public-key-file"))
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "infra-production-0:T7ZxFWDaNjyEiiYDe6uZn0eq+77gORGkdec+kYwaB1M="
    ];
  };

  services.telegraf.extraConfig.inputs.prometheus = {
    urls = [
      "http://127.0.0.1:${
        toString config.services.promtail.server.http_listen_port
      }/metrics"
      "http://127.0.0.1:${toString config.services.spongix.port}/metrics"
    ];
    metric_version = 1;
  };

  systemd.services.spongix-service = (pkgs.consulRegister {
    pkiFiles.caCertFile = "/etc/ssl/certs/ca.pem";
    service = {
      name = "spongix";
      port = 7745;
      tags = [ "spongix" "server" ];

      checks = {
        gluster-tcp = {
          interval = "10s";
          timeout = "5s";
          tcp = "localhost:7745";
        };
      };
    };
  }).systemdService;
}
