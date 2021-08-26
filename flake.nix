{
  description = "Bitte for infra-ops";

  inputs = {
    utils.url = "github:kreisys/flake-utils";
    bitte.url = "github:input-output-hk/bitte/nix-driver-with-profiles";
    bitte.inputs.bitte-cli.url = "github:input-output-hk/bitte-cli/v0.3.5";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "bitte/nixpkgs";
    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci.inputs.bitte.follows = "bitte";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    ipxed.url = "github:input-output-hk/ipxed";
  };

  outputs = { self, nixpkgs, utils, bitte, ipxed, ... }@inputs:
    utils.lib.simpleFlake {
      inherit nixpkgs;
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte ipxed ];
      overlay = import ./overlay.nix inputs;

      extraOutputs = let
        hashiStack = bitte.lib.mkHashiStack {
          flake = self // {
            inputs = self.inputs // { inherit (bitte.inputs) terranix; };
          };
          domain = "infra.aws.iohkdev.io";
        };
      in {
        inherit self inputs;
        inherit (hashiStack)
          clusters nomadJobs nixosConfigurations consulTemplates;
      };

      # simpleFlake ignores devShell if we don't specify this.
      packages = { }: { };

      hydraJobs = { ipxed }@pkgs: pkgs;

      devShell = { bitteShellCompat }:
        (bitteShellCompat {
          inherit self;
          cluster = "infra-production";
          profile = "infra-ops";
          region = "us-west-1";
          domain = "infra.aws.iohkdev.io";
        });
    };
}
