{ self, lib, pkgs, config, terralib, ... }:
let
  inherit (config) cluster;
  inherit (terralib) var regions awsProviderNameFor;
  inherit (import ./security-group-rules.nix {
    inherit config pkgs lib terralib;
  })
    securityGroupRules;

  inherit (self.inputs) bitte;
in {

  imports = [ ./vault-raft-storage.nix ./secrets.nix ];

  # avoid CVE-2021-4034 (PwnKit)
  security.polkit.enable = false;

  services.consul.policies.developer.servicePrefix."infra-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies = {
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
        capabilities = [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
      };
      node.policy = "read";
    };

    cicero = {
      description = "Cicero (Run Jobs and monitor them)";
      agent.policy = "read";
      node.policy = "read";
      namespace."*" = {
        policy = "read";
        capabilities = [ "submit-job" "dispatch-job" "read-logs" "read-job" ];
      };
    };

    nomad-follower = {
      description = "Nomad Follower (Collect logs from cicero allocations)";
      agent.policy = "read";
      namespace.cicero = {
        policy = "read";
        capabilities = [ "read-job" ];
      };
    };
  };

  services.vault.policies = let
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
      aws = [{ inherit (config.cluster) region; }] ++ (lib.forEach regions
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

  services.nomad.namespaces = {
    infra-default.description = "Infra Default";
    cicero.description = "Cicero";
  };

  nix.binaryCaches = [ "https://hydra.iohk.io" "https://cache.nixos.org" ];

  nix.binaryCachePublicKeys = [
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
        desiredCapacity = 2;
      }
      {
        region = "us-east-2";
        desiredCapacity = 2;
      }
      # Only 2 AZs available for new customers
      #{
      #  region = "us-west-1";
      #  desiredCapacity = 0;
      #}
    ] (args:
      let
        attrs = {
          desiredCapacity = 1;
          instanceType = "m5.8xlarge";
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;
          node_class = "production";

          modules = [
            bitte.profiles.client
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            ./client.nix
          ];

          securityGroupRules = {
            inherit (securityGroupRules) internet internal ssh;
          };
        } // args;
        asgName = "client-${attrs.region}-${
            builtins.replaceStrings [ "." ] [ "-" ] attrs.instanceType
          }";
      in lib.nameValuePair asgName attrs));

    coreNodes = {
      core-1 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.0.10";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-1;

        modules = [ bitte.profiles.core bitte.profiles.bootstrapper ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-2 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.1.10";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-2;

        modules = [ bitte.profiles.core ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.2.10";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-3;

        modules = [ bitte.profiles.core ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 100;
        route53.domains =
          [ "docker.${cluster.domain}" "vbk.${cluster.domain}" ];

        modules = [
          bitte.profiles.monitoring
          ./vault-backend.nix
          # ./ipxe.nix
          # ./nfs.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https nfs-portmapper nfs;
        };
      };

      routing = {
        instanceType = "t3a.small";
        privateIP = "172.16.1.40";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ bitte.profiles.routing ./traefik.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http routing;
        };
      };

      hydra = {
        instanceType = "m5.4xlarge";
        privateIP = "172.16.0.52";
        ami = "ami-050be818e0266b741";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 600;
        route53.domains = [ "hydra-wg.${cluster.domain}" ];

        modules = [ bitte.profiles.common ./bitte-ci.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh wireguard;
        };
      };

      storage-0 = {
        instanceType = "t3a.small";
        privateIP = "172.16.0.30";
        ami = "ami-050be818e0266b741";
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
        ami = "ami-050be818e0266b741";
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
        ami = "ami-050be818e0266b741";
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
