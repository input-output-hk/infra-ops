{ self, lib, pkgs, config, ... }:
let
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

  bitte = self.inputs.bitte;
in {
  services.consul.policies.developer.servicePrefix."catalyst-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies.admin.namespace."catalyst-*".policy = "write";
  services.nomad.policies.developer.namespace."catalyst-*".policy = "write";

  services.nomad.namespaces = {
    catalyst-ceph = { description = "Catalyst (ceph)"; };
  };

  cluster = {
    name = "infra-production";
    developerGithubNames = [ ];
    developerGithubTeamNames = [ "devops" ];
    domain = "infra.aws.iohkdev.io";
    kms =
      "arn:aws:kms:us-west-1:212281588582:key/da0d55b9-3deb-4775-8e00-30eee3042966";
    s3Bucket = "iohk-infra";
    terraformOrganization = "iohk-infra";

    s3CachePubKey = lib.fileContents ../../../encrypted/nix-public-key-file;
    adminNames = [ "craige.mcwhirter" "john.lotoski" "michael.fellinger" ];

    flakePath = ../../..;

    autoscalingGroups = lib.listToAttrs (lib.forEach [
      # NOTE: Regions with < 3 AZs not yet supported
      {
        region = "eu-central-1";
        desiredCapacity = 0;
      }
      {
        region = "us-east-2";
        desiredCapacity = 0;
      }
      # Only 2 AZs available for new customers
      #{
      #  region = "us-west-1";
      #  desiredCapacity = 0;
      #}
    ] (args:
      let
        attrs = ({
          desiredCapacity = 1;
          instanceType = "c5.2xlarge";
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          modules = [
            (bitte + /profiles/client.nix)
            self.inputs.ops-lib.nixosModules.zfs-runtime
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            ./secrets.nix
          ];

          securityGroupRules = {
            inherit (securityGroupRules) internet internal ssh;
          };
        } // args);
        asgName = "client-${attrs.region}-${
            builtins.replaceStrings [ "." ] [ "-" ] attrs.instanceType
          }";
      in lib.nameValuePair asgName attrs));

    instances = {
      core-1 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.0.10";
        subnet = cluster.vpc.subnets.core-1;

        modules = [
          (bitte + /profiles/core.nix)
          (bitte + /profiles/bootstrapper.nix)
          ./secrets.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-2 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 40;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ (bitte + /profiles/monitoring.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http https;
        };
      };
    };
  };
}
