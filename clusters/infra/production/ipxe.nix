{ self, ... }: {
  imports = [ self.inputs.ipxed.nixosModules.ipxed ];
  services.ipxed = {
    enable = true;
    allow = [ "input-output-hk/infra-ops" ];
  };
}
