inputs: final: prev: {
  hydra-unstable =
    inputs.nixpkgs-unstable.legacyPackages.${prev.system}.hydra-unstable;
  bitte-ci = inputs.bitte-ci.packages.${prev.system};
}
