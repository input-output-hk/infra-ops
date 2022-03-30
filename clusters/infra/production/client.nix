{ pkgs, lib, self, ... }: {
  profiles.auxiliaries.builder.remoteBuilder.buildMachine.supportedFeatures =
    [ "big-parallel" ];

  services.nomad.client.host_volume.marlowe = {
    path = "/mnt/gv0/nomad/marlowe";
    read_only = false;
  };

  services.nomad.client.chroot_env =
    lib.mkForce { "/etc/passwd" = "/etc/passwd"; };

  systemd.services."mnt-gv0.mount" = {
    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
    };
  };

  systemd.services.nomad.serviceConfig = {
    JobTimeoutSec = "600s";
    JobRunningTimeoutSec = "600s";
  };
}
