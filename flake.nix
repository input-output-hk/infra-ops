{
  description = "Bitte for infra-ops";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nomad-driver-nix.url = "github:input-output-hk/nomad-driver-nix";
    nix-inclusive.url = "github:input-output-hk/nix-inclusive";
    nomad-follower.url = "github:input-output-hk/nomad-follower";
    spongix.url = "github:input-output-hk/spongix";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, utils, bitte, spongix, devshell, ... }@inputs:
    let
      system = "x86_64-linux";
      domain = "infra.aws.iohkdev.io";

      overlay = nixpkgs.lib.composeManyExtensions overlays;

      overlays =
        [ (import ./overlay.nix inputs) bitte.overlay devshell.overlay ];

      pkgs = import nixpkgs {
        inherit overlays system;
        config.allowUnfree = true;
      };

      bitteStack = let
        stack = bitte.lib.mkBitteStack {
          inherit self inputs domain overlays;
          bitteProfile = ./clusters/infra/production;
          deploySshKey = "./secrets/ssh-infra-production";
          hydrateModule = ./clusters/infra/production/hydrate.nix;
        };
      in stack // { deploy = stack.deploy // { autoRollback = false; }; };
    in {
      inherit overlay;
      legacyPackages."${system}" = pkgs;

      devShell."${system}" = pkgs.devshell.mkShell {
        imports = [ bitte.inputs.cli.devshellModules.bitte ];
        commands = [ ];
        bitte = {
          cluster = "infra-production";
          domain = "infra.aws.iohkdev.io";
          namespace = "default";
          provider = "AWS";
          cert = null;
          aws_profile = "infra-ops";
          aws_region = "us-west-1";
          aws_autoscaling_groups =
            self.clusters.infra-production._proto.config.cluster.autoscalingGroups;
        };
      };
    } // bitteStack;
}
