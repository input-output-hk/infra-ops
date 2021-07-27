{ pkgs, lib, ... }: {
  services.nomad.client.chroot_env = lib.mkForce {
    "/etc/passwd" = "/etc/passwd";
  };
}
