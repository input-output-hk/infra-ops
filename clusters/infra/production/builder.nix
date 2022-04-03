{ inputs, ... }: {
  imports = [
    ./spongix.nix
    inputs.bitte.profiles.common
    inputs.bitte.profiles.consul-client
    inputs.bitte.profiles.consul-client
    inputs.bitte.profiles.vault-common
    inputs.bitte.profiles.auxiliaries-builder
  ];
  nix.systemFeatures = [ "big-parallel" ];
  services.vault-agent.role = "hydra";
}
