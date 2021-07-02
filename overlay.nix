inputs: final: prev: {
  hydra-unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.hydra-unstable;
}
