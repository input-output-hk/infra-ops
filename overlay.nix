inputs: final: prev: {
  hydra-unstable =
    inputs.nixpkgs-unstable.legacyPackages.${prev.system}.hydra-unstable;
  bitte-ci = inputs.bitte-ci.packages.${prev.system};
  bitteShellCompat = final.callPackage (builtins.fetchurl { url = "https://raw.githubusercontent.com/input-output-hk/bitte/master/pkgs/bitte-shell.nix"; sha256 = "sha256:1k2k5qsvq5ii2gj7plphp5h6zn299xbqjxlpn4svbn52yklqpkbw"; }) { };
}
