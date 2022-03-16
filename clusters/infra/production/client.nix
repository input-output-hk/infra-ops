{ pkgs, lib, self, ... }: {
  profiles.auxiliaries.builder.remoteBuilder.buildMachine.supportedFeatures =
    [ "big-parallel" ];

  services.nomad.client.chroot_env =
    lib.mkForce { "/etc/passwd" = "/etc/passwd"; };

  systemd.services.nomad-follower = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nomad.service" ];

    environment = {
      VAULT_ADDR = "http://127.0.0.1:8200";
      NOMAD_ADDR = "https://127.0.0.1:4646";
      NOMAD_TOKEN_FILE = "/run/keys/vault-token";
    };

    path = with pkgs; [ vector ];

    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
      StateDirectory = "nomad-follower";
      ExecStart = toString [
        "@${pkgs.nomad-follower}/bin/nomad-follower"
        "nomad-follower"
        "--state"
        "/var/lib/nomad-follower"
        "--alloc"
        "/var/lib/nomad/alloc/%s/alloc"
        "--loki-url"
        "http://monitoring:3100"
        "--namespace"
        "cicero"
      ];
      WorkingDirectory = "/var/lib/nomad-follower";
    };
  };
}
