{ pkgs, ... }: {
  services.nomad.client.chroot_env = {
    "${builtins.unsafeDiscardStringContext pkgs.cacert}/etc/ssl/certs" =
      "/etc/ssl/certs";
    "/etc/passwd" = "/etc/passwd";
  };
}
