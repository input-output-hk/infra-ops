{ pkgs, lib, self, ... }: {
  profiles.auxiliaries.builder.remoteBuilder.buildMachine.supportedFeatures =
    [ "big-parallel" ];

  services.nomad.client.host_volume.marlowe = {
    path = "/mnt/gv0/nomad/marlowe";
    read_only = false;
  };

  services.nomad.client.chroot_env =
    lib.mkForce { "/etc/passwd" = "/etc/passwd"; };

  services.nomad-follower.enable = true;

  services.vault-agent.templates."/run/keys/nomad-follower-token" = {
    command =
      "${pkgs.systemd}/bin/systemctl --no-block reload nomad-follower.service || true";
    contents = ''
      {{- with secret "nomad/creds/nomad-follower" }}{{ .Data.secret_id }}{{ end -}}'';
  };
}
