{ self, lib, pkgs, config, ... }:
let
  inherit (config) cluster;
  inherit (pkgs.terralib) var regions awsProviderNameFor;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

  bitte = self.inputs.bitte;
in {

  imports = [ ./vault-raft-storage.nix ./secrets.nix ./iam.nix ];

  services.consul.policies.developer.servicePrefix."infra-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies.admin.namespace."infra-*".policy = "write";
  services.nomad.policies.developer.namespace."infra-*".policy = "write";

  services.nomad.policies.bitte-ci = {
    description = "Bitte CI (Run Jobs and monitor them)";
    namespace.default = {
      policy = "read";
      capabilities = [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
    };
  };

  services.vault.policies = {
    admin.path."secret/*".capabilities =
      [ "create" "read" "update" "delete" "list" ];
    terraform.path."secret/data/vbk/*".capabilities =
      [ "create" "read" "update" "delete" "list" ];
    terraform.path."secret/metadata/vbk/*".capabilities = [ "delete" ];
    vit-terraform.path."secret/data/vbk/vit-testnet/*".capabilities =
      [ "create" "read" "update" "delete" "list" ];
    vit-terraform.path."secret/metadata/vbk/vit-testnet/*".capabilities =
      [ "create" "read" "update" "delete" "list" ];
  };

  tf.core.configuration = let
    mkStorage = name: {
      availability_zone = var "aws_instance.${name}.availability_zone";
      encrypted = true;
      iops = 3000; # 3000..16000
      size = 2; # GiB
      type = "gp3";
      kms_key_id = cluster.kms;
      throughput = 125; # 125..1000 MiB/s
    };

    mkAttachment = name: {
      device_name = "/dev/sdh";
      volume_id = var "aws_ebs_volume.${name}.id";
      instance_id = var "aws_instance.${name}.id";
    };
  in {
    resource.aws_volume_attachment = {
      storage-0 = mkAttachment "storage-0";
      storage-1 = mkAttachment "storage-1";
      storage-2 = mkAttachment "storage-2";
    };

    resource.aws_ebs_volume = {
      storage-0 = mkStorage "storage-0";
      storage-1 = mkStorage "storage-1";
      storage-2 = mkStorage "storage-2";
    };
  };

  tf.infra.configuration = {
    terraform.backend.http =
      let vbk = "https://vbk.infra.aws.iohkdev.io/state/${cluster.name}/infra";
      in {
        address = vbk;
        lock_address = vbk;
        unlock_address = vbk;
      };

    terraform.required_providers =
      lib.getAttrs [ "aws" "vault" ] pkgs.terraform-provider-versions;

    provider = {
      aws = [{ region = config.cluster.region; }] ++ (lib.forEach regions
        (region: {
          inherit region;
          alias = awsProviderNameFor region;
        }));

      vault = { };
    };

    resource.vault_github_auth_backend.terraform = {
      organization = "input-output-hk";
      path = "github-terraform";
      tune = [{
        max_lease_ttl = "24h";
        default_lease_ttl = "12h";
        allowed_response_headers = null;
        audit_non_hmac_request_keys = null;
        audit_non_hmac_response_keys = null;
        listing_visibility = null;
        passthrough_request_headers = null;
        token_type = "default-service";
      }];
    };

    resource.vault_github_team.devops = {
      backend = var "vault_github_auth_backend.terraform.path";
      team = "devops";
      policies = [ "terraform" ];
    };

    resource.vault_github_team.jormungandr-devops = {
      backend = var "vault_github_auth_backend.terraform.path";
      team = "jormungandr-devops";
      policies = [ "vit-terraform" ];
    };
  };

  services.nomad.namespaces = { infra-default.description = "Infra Default"; };

  nix.binaryCaches = [
    "https://hydra.iohk.io"
    "https://cache.nixos.org"
    "https://hydra.mantis.ist"
  ];

  nix.binaryCachePublicKeys = [
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hydra.mantis.ist-1:4LTe7Q+5pm8+HawKxvmn2Hx0E3NbkYjtf1oWv+eAmTo="
  ];

  cluster = {
    name = "infra-production";
    developerGithubNames = [ ];
    developerGithubTeamNames = [ ];
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
        desiredCapacity = 1;
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
          instanceType = "m5.8xlarge";
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          modules = [
            (bitte + /profiles/client.nix)
            self.inputs.ops-lib.nixosModules.zfs-runtime
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            ./client.nix
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

        modules =
          [ (bitte + /profiles/core.nix) (bitte + /profiles/bootstrapper.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-2 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;

        modules = [ (bitte + /profiles/core.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;

        modules = [ (bitte + /profiles/core.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 40;
        route53.domains = [
          "consul.${cluster.domain}"
          "docker.${cluster.domain}"
          "monitoring.${cluster.domain}"
          "nomad.${cluster.domain}"
          "vault.${cluster.domain}"
          "vbk.${cluster.domain}"
        ];

        modules = [ (bitte + /profiles/monitoring.nix) ./vault-backend.nix ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https wireguard;
        };
      };

      routing = {
        instanceType = "t3a.small";
        privateIP = "172.16.1.40";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ (bitte + /profiles/routing.nix) ./traefik.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http routing;
        };
      };

      hydra = {
        instanceType = "m5.4xlarge";

        privateIP = "172.16.0.52";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 600;
        route53.domains = [ "hydra-wg.${cluster.domain}" ];

        modules =
          [ (bitte + /profiles/monitoring.nix) ./hydra.nix ./bitte-ci.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh wireguard;
        };
      };

      storage-0 = {
        instanceType = "t3a.small";
        privateIP = "172.16.0.30";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 40;

        modules = [ (bitte + /profiles/glusterfs/storage.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-1 = {
        instanceType = "t3a.small";
        privateIP = "172.16.1.20";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 40;

        modules = [ (bitte + /profiles/glusterfs/storage.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-2 = {
        instanceType = "t3a.small";
        privateIP = "172.16.2.20";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 40;

        modules = [ (bitte + /profiles/glusterfs/storage.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };
    };
  };
}
