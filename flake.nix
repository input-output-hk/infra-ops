{
  description = "Bitte for infra-ops";

  inputs = {
    bitte.url = "github:input-output-hk/bitte/glusterfs";
    bitte-cli.follows = "bitte/bitte-cli";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "bitte/nixpkgs";
    terranix.follows = "bitte/terranix";
    utils.follows = "bitte/utils";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
  };

  outputs = { self, nixpkgs, utils, ops-lib, bitte, ... }@inputs:
    let
      hashiStack = bitte.mkHashiStack {
        flake = self;
        rootDir = ./.;
        inherit pkgs;
        domain = "infra.aws.iohkdev.io";
      };

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (final: prev: { inherit (hashiStack) clusters dockerImages; })
          bitte.overlay
          (import ./overlay.nix inputs)
        ];
      };

      nixosConfigurations = hashiStack.nixosConfigurations;
    in {
      clusters.x86_64-linux = hashiStack.clusters;
      inherit nixosConfigurations;
      legacyPackages.x86_64-linux = pkgs;
      devShell.x86_64-linux = pkgs.devShell;
      hydraJobs.x86_64-linux = {
        inherit (pkgs)
          devShellPath bitte nixFlakes sops terraform-with-plugins cfssl consul
          nomad vault-bin cue grafana haproxy grafana-loki victoriametrics
          vault-backend;
      } // (pkgs.lib.mapAttrs (_: v: v.config.system.build.toplevel)
        nixosConfigurations);
    };
}

/* zfs-ami = import "${nixpkgs}/nixos" {
     configuration = { pkgs, lib, ... }: {
       imports = [
         ops-lib.nixosModules.make-zfs-image
         ops-lib.nixosModules.zfs-runtime
         "${nixpkgs}/nixos/modules/profiles/headless.nix"
         "${nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
       ];
       nix.package = self.packages.x86_64-linux.nixFlakes;
       nix.extraOptions = ''
         experimental-features = nix-command flakes
       '';
       systemd.services.amazon-shell-init.path = [ pkgs.sops ];
       nixpkgs.config.allowUnfreePredicate = x:
         builtins.elem (lib.getName x) [ "ec2-ami-tools" "ec2-api-tools" ];
       zfs.regions = [
         "eu-west-1"
         "ap-northeast-1"
         "ap-northeast-2"
         "eu-central-1"
         "us-east-2"
       ];
     };
     system = "x86_64-linux";
   };
*/
