{ self, config, lib, pkgs, ... }: {
  imports = [ self.inputs.ipxed.nixosModules.ipxed ];

  services.ipxed = {
    enable = true;
    host = "0.0.0.0";
    allow =
      [ "github:input-output-hk/infra-ops" "github:input-output-hk/moe-ops" ];
    tokenFile = "/run/keys/ipxed-token";
  };

  systemd.services.ipxed-service = (pkgs.consulRegister {
    service = {
      name = "ipxed";
      port = config.services.ipxed.port;
      tags = [
        "ingress"
        "traefik.enable=true"
        "traefik.http.routers.ipxed.rule=Host(`ipxe.${config.cluster.domain}`) && PathPrefix(`/`)"
        "traefik.http.routers.ipxed.entrypoints=https"
        "traefik.http.routers.ipxed.tls=true"
      ];

      checks = {
        ipxed = {
          interval = "10s";
          timeout = "5s";
          tcp = "127.0.0.1:${toString config.services.ipxed.port}";
        };
      };
    };
  }).systemdService;

  secrets.install.ipxed = rec {
    source = config.secrets.encryptedRoot + "/ipxed.json";
    target = "/run/keys/ipxed.json";
    script = ''
      PATH="${lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}"
      jq -r -e .token < ${target} > /run/keys/ipxed-token

      github_token="$(jq -r -e .github < ${target})"

      echo "machine github.com login api password $github_token" > /etc/nix/netrc
      echo "machine api.github.com login api password $github_token" >> /etc/nix/netrc

      chmod 0440 /etc/nix/netrc
    '';
  };
}
