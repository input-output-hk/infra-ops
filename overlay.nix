inputs: final: prev: {
  inherit (inputs.nixpkgs-unstable.legacyPackages."${prev.system}")
    hydra-unstable vector;
  bitte-ci = inputs.bitte-ci.packages."${prev.system}";
  inherit (inputs.nomad-driver-nix.packages."${prev.system}") nomad-driver-nix;
  nomad-follower = inputs.nomad-follower.defaultPackage."${prev.system}";

  jobs = let
    src =
      inputs.nix-inclusive.lib.inclusive ./. [ ./cue.mod ./deploy.cue ./jobs ];

    exported = final.runCommand "defs" { buildInputs = [ final.cue ]; } ''
      cd ${src}
      cue export -e jobs > $out
    '';

    original = builtins.fromJSON (builtins.readFile exported);

    runner = name: value:
      let jobFile = builtins.toFile "${name}.json" (builtins.toJSON value);
      in final.writeShellScriptBin name ''
        echo "Running job: ${jobFile}"
        ${final.nomad}/bin/nomad job run ${jobFile}
      '';
  in prev.lib.mapAttrs runner original;
}
