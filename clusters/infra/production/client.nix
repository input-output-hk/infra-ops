{ pkgs, lib, self, ... }: {
  services.nomad.client.chroot_env =
    lib.mkForce { "/etc/passwd" = "/etc/passwd"; };

  services.nomad.pluginDir =
    "${self.inputs.nomad-driver-nix.defaultPackage.x86_64-linux}/bin";
}
