inputs: final: prev: {
  hydra-unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.hydra-unstable;
  bitte-ci-frontend = inputs.bitte-ci-frontend.packages.${prev.system}.bitte-ci-frontend;
  bitte-ci = inputs.bitte-ci.packages.${prev.system}.bitte-ci;
}
