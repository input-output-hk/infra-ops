inputs: final: prev:
let
  inherit (prev) system;
  inherit (inputs.nix-inclusive.lib) inclusive;
in {
  inherit (inputs.nixpkgs-unstable.legacyPackages."${system}")
    hydra-unstable vector traefik;

  inherit (inputs.nomad-driver-nix.packages."${system}") nomad-driver-nix;

  spongix = inputs.spongix.defaultPackage."${system}";

  job = let
    src = inclusive ./. [ ./cue.mod ./deploy.cue ./jobs ];

    exported = prev.runCommand "defs" { buildInputs = [ prev.cue ]; } ''
      cd ${src}
      cue export -e jobs -t sha=${inputs.self.rev or "dirty"} > $out
    '';

    original = builtins.fromJSON (builtins.readFile exported);

    runner = name: value:
      let jobFile = builtins.toFile "${name}.json" (builtins.toJSON value);
      in prev.writeShellScriptBin name ''
        echo "Running job: ${jobFile}"
        ${prev.nomad}/bin/nomad job run ${jobFile}
      '';
  in prev.lib.mapAttrs runner original;
}
