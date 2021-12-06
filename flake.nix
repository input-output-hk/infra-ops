{
  description = "Bitte for infra-ops";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "bitte/nixpkgs";
    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci.inputs.bitte.follows = "bitte";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    ipxed.url = "github:input-output-hk/ipxed";
    nomad-driver-nix.url = "github:input-output-hk/nomad-driver-nix";
    nix-inclusive.url = "github:input-output-hk/nix-inclusive";
    nomad-follower.url = "github:input-output-hk/nomad-follower";
  };

  outputs = { self, nixpkgs, utils, bitte, ipxed, ... }@inputs:
    utils.lib.simpleFlake {
      inherit nixpkgs;
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte ipxed ];
      overlay = import ./overlay.nix inputs;

      extraOutputs = let
        bitteStack = bitte.lib.mkBitteStack {
          inherit self inputs;
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays =
              [ bitte.overlay ipxed.overlay (import ./overlay.nix inputs) ];
          };

          domain = "infra.aws.iohkdev.io";
          clusters = ./clusters;
          deploySshKey = "./secrets/ssh-infra-production";
          hydrateModule = _: { };
        };
      in { inherit self inputs; } // bitteStack;

      # simpleFlake ignores devShell if we don't specify this.
      packages = { jobs }@pkgs: pkgs;

      hydraJobs = { ipxed }@pkgs: pkgs;

      devShell = { bitteShell, cue }:
        bitteShell {
          inherit self;
          cluster = "infra-production";
          namespace = "default";
          profile = "infra-ops";
          region = "us-west-1";
          domain = "infra.aws.iohkdev.io";
          extraPackages = [ cue ];
        };
    };
}
