{
  description = "Bitte for infra-ops";

  inputs = {
    utils.url = "github:numtide/flake-utils";

    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte/hydra-server";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    # --------------------------------------------------------------

    bitte-ci.url = "github:input-output-hk/bitte-ci";
    bitte-ci.inputs.bitte.follows = "bitte";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    ipxed.url = "github:input-output-hk/ipxed";
    nomad-driver-nix.url = "github:input-output-hk/nomad-driver-nix";
    nix-inclusive.url = "github:input-output-hk/nix-inclusive";
    nomad-follower.url = "github:input-output-hk/nomad-follower";
    nix-cache-proxy.url = "github:input-output-hk/nix-cache-proxy";
  };

  outputs = { self, nixpkgs, utils, bitte, ipxed, nix-cache-proxy, ... }@inputs:
    (let
      overlays = [
        pkgsOverlay
        auxOverlay
        bitte.overlay
        ipxed.overlay
        nix-cache-proxy.overlay
      ];

      pkgsOverlay = final: prev: {
        inherit (inputs.nixpkgs-unstable.legacyPackages."${prev.system}")
          hydra-unstable vector;
        bitte-ci = inputs.bitte-ci.packages."${prev.system}";
        inherit (inputs.nomad-driver-nix.packages."${prev.system}")
          nomad-driver-nix;
        nomad-follower = inputs.nomad-follower.defaultPackage."${prev.system}";
        inherit (inputs.nixpkgs-unstable.legacyPackages."${prev.system}")
          traefik;
      };

      auxOverlay = final: prev: {
        jobs = let
          src = inputs.nix-inclusive.lib.inclusive ./. [
            ./cue.mod
            ./deploy.cue
            ./jobs
          ];

          exported = final.runCommand "defs" { buildInputs = [ final.cue ]; } ''
            cd ${src}
            cue export -e jobs -t sha=${inputs.self.rev or "dirty"} > $out
          '';

          original = builtins.fromJSON (builtins.readFile exported);

          runner = name: value:
            let
              jobFile = builtins.toFile "${name}.json" (builtins.toJSON value);
            in final.writeShellScriptBin name ''
              echo "Running job: ${jobFile}"
              ${final.nomad}/bin/nomad job run ${jobFile}
            '';
        in prev.lib.mapAttrs runner original;
      };

      pkgsForSystem = system:
        import nixpkgs {
          inherit overlays system;
          config.allowUnfree = true;
        };

      bitteStack = bitte.lib.mkBitteStack {
        inherit self inputs;
        pkgs = pkgsForSystem "x86_64-linux";
        domain = "infra.aws.iohkdev.io";
        clusters = ./clusters;
        deploySshKey = "./secrets/ssh-infra-production";
        hydrateModule = _: {
          tf.hydrate-cluster.configuration.locals.policies = {
            consul.developer.servicePrefix."infra-" = {
              policy = "write";
              intentions = "write";
            };

            vault = let
              c = "create";
              r = "read";
              u = "update";
              d = "delete";
              l = "list";
            in {
              admin.path."secret/*".capabilities = [ c r u d l ];
              terraform.path."secret/data/vbk/*".capabilities = [ c r u d l ];
              terraform.path."secret/metadata/vbk/*".capabilities = [ d ];
              vit-terraform.path."secret/data/vbk/vit-testnet/*".capabilities =
                [ c r u d l ];
              vit-terraform.path."secret/metadata/vbk/vit-testnet/*".capabilities =
                [ c r u d l ];

              cicero.path = {
                "auth/token/lookup".capabilities = [ u ];
                "auth/token/lookup-self".capabilities = [ r ];
                "auth/token/renew-self".capabilities = [ u ];
                "kv/data/cicero/*".capabilities = [ r l ];
                "kv/metadata/cicero/*".capabilities = [ r l ];
                "nomad/creds/cicero".capabilities = [ r u ];
              };

              client.path."nomad/creds/nomad-follower".capabilities = [ r u ];
            };

            nomad = {
              admin = {
                description = "Admin policies";
                namespace."infra-*".policy = "write";
              };

              developer = {
                description = "Dev policies";
                namespace."infra-*".policy = "write";
              };

              bitte-ci = {
                description = "Bitte CI (Run Jobs and monitor them)";
                namespace.default = {
                  policy = "read";
                  capabilities =
                    [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
                };
                node.policy = "read";
              };

              cicero = {
                description = "Cicero (Run Jobs and monitor them)";
                agent.policy = "read";
                node.policy = "read";
                namespace."*" = {
                  policy = "read";
                  capabilities =
                    [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
                };
              };

              nomad-follower = {
                description =
                  "Nomad Follower (Collect logs from cicero allocations)";
                agent.policy = "read";
                namespace.cicero = {
                  policy = "read";
                  capabilities = [ "read-job" ];
                };
              };
            };
          };
        };
      };

    in utils.lib.eachSystem [ "x86_64-linux" ] (system: rec {

      legacyPackages = pkgsForSystem system;

      devShell = legacyPackages.bitteShell rec {
        inherit self;
        cluster = "infra-production";
        namespace = "default";
        profile = "infra-ops";
        region = "us-west-1";
        domain = "infra.aws.iohkdev.io";
        extraPackages = with legacyPackages; [ cue ];
      };

    }) // {
      # eta reduce not possibe since flake check validates for "final" / "prev"
      overlay = nixpkgs.lib.composeManyExtensions overlays;
    } // bitteStack)

  ; # outputs

}
