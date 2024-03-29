{ self, lib, pkgs, config, terralib, ... }:
let
  inherit (config) cluster;
  inherit (terralib) var regions awsProviderNameFor;
  inherit (import ./security-group-rules.nix {
    inherit config pkgs lib terralib;
  })
    securityGroupRules;

  inherit (self.inputs) bitte;

  # NOTE: switch back to the bitte default userData value when updating the AMIs
  # for now we hardcode this here to prevent terraform from destroying the cluster.
  ami = "ami-050be818e0266b741";
  userData = ''
    ### https://nixos.org/channels/nixpkgs-unstable nixos
    { pkgs, config, ... }: {
      imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];

      nix = {
        package = pkgs.nixFlakes;
        extraOptions = '''
          show-trace = true
          experimental-features = nix-command flakes ca-references
        ''';
        binaryCaches = [
          "https://hydra.iohk.io"
          "s3://iohk-infra/infra/binary-cache/?region=us-west-1"
        ];
        binaryCachePublicKeys = [
          "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
          "infra-production-0:T7ZxFWDaNjyEiiYDe6uZn0eq+77gORGkdec+kYwaB1M="
        ];
      };

      environment.etc.ready.text = "true";
    }
  '';
in {
  imports = [
    ./vault-raft-storage.nix
    ./secrets.nix
    ./github-secrets.nix
    ./spongix-user.nix
  ];

  # avoid CVE-2021-4034 (PwnKit)
  security.polkit.enable = false;

  # Growing a gluster (growing bricks):
  #
  # GlusterFS doesn't support growing bricks directly, so they have to be
  # replaced with bigger ones.
  #
  # We really would like to reuse the original EBS volumes, so we first grow
  # those, add 3 identical new volumes, and then replace the old bricks with
  # bricks on the new volumes. After this is done, we can replace them back and
  # remove the temporary EBS volumes.
  #
  # Create and attach new EBS volume
  # Format and mount it:
  #   {
  #     fileSystems."/data/brick2" = {
  #       label = "brick";
  #       device = "/dev/nvme2n1";
  #       fsType = "xfs";
  #       formatOptions = "-i size=512";
  #       autoFormat = true;
  #     };
  #   }
  #
  # Grow the original EBS volume:
  # $ xfs_growfs /dev/nvme1n1
  #
  # Migrate data over to the new volume:
  # $ gluster volume replace-brick gv0 storage-0:/data/brick1/gv0 storage-0:/data/brick2/gv0 commit force
  #
  # Check health of the the cluster
  # $ gluster volume heal gv0 info
  # Number of entries that heal returns should be 0
  #
  # Replace the temporary brick with the original EBS volume:
  # $ gluster volume replace-brick gv0 storage-0:/data/brick2/gv0 storage-0:/data/brick1/gv0 commit force
  # $ gluster volume heal gv0 info
  #
  # Remove the brick2 mountpoints again.
  # Then finally remove the temporary EBS volumes.

  tf.core.configuration = let
    mkStorage = host: {
      availability_zone = var "aws_instance.${host}.availability_zone";
      encrypted = true;
      iops = 3000; # 3000..16000
      size = 500; # GiB
      type = "gp3";
      kms_key_id = cluster.kms;
      throughput = 125; # 125..1000 MiB/s
    };

    mkAttachment = host: volume: device_name: {
      inherit device_name;
      volume_id = var "aws_ebs_volume.${volume}.id";
      instance_id = var "aws_instance.${host}.id";
    };
  in {
    resource.aws_volume_attachment = {
      storage-0 = mkAttachment "storage-0" "storage-0" "/dev/sdh";
      storage-1 = mkAttachment "storage-1" "storage-1" "/dev/sdh";
      storage-2 = mkAttachment "storage-2" "storage-2" "/dev/sdh";
      # use this for growing the storage:
      # storage-0-tmp = mkAttachment "storage-0" "storage-0-tmp" "/dev/sdi";
      # storage-1-tmp = mkAttachment "storage-1" "storage-1-tmp" "/dev/sdi";
      # storage-2-tmp = mkAttachment "storage-2" "storage-2-tmp" "/dev/sdi";
    };

    resource.aws_ebs_volume = {
      storage-0 = mkStorage "storage-0";
      storage-1 = mkStorage "storage-1";
      storage-2 = mkStorage "storage-2";
      # use this for growing the storage:
      # storage-0-tmp = mkStorage "storage-0";
      # storage-1-tmp = mkStorage "storage-1";
      # storage-2-tmp = mkStorage "storage-2";
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

    resource.vault_github_team.plutus-devops = {
      backend = var "vault_github_auth_backend.terraform.path";
      team = "plutus-devops";
      policies = [ "plutus-terraform" ];
    };
  };

  services.nomad.namespaces = {
    infra-default.description = "Infra Default";
    cicero.description = "Cicero";
    midnight-ng.description = "Midnight NG";
    marlowe.description = "Marlowe";
  };

  cluster = {
    name = "infra-production";
    developerGithubNames = [ ];
    developerGithubTeamNames = [ "plutus-devops" ];
    domain = "infra.aws.iohkdev.io";
    kms =
      "arn:aws:kms:us-west-1:212281588582:key/da0d55b9-3deb-4775-8e00-30eee3042966";
    s3Bucket = "iohk-infra";

    s3CachePubKey =
      "infra-production-0:T7ZxFWDaNjyEiiYDe6uZn0eq+77gORGkdec+kYwaB1M=";
    adminNames = [ "craige.mcwhirter" "john.lotoski" "michael.fellinger" ];

    flakePath = ../../..;

    builder = "hydra";

    autoscalingGroups = lib.listToAttrs (lib.forEach [
      # NOTE: Regions with < 3 AZs not yet supported
      {
        region = "eu-central-1";
        desiredCapacity = 2;
        node_class = "production";
      }
      {
        region = "us-east-2";
        desiredCapacity = 2;
        node_class = "production";
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

          modules = [
            bitte.profiles.client
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            bitte.profiles.nomad-follower
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
        subnet = cluster.vpc.subnets.core-1;
        inherit ami userData;

        modules =
          [ bitte.profiles.core bitte.profiles.bootstrapper ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-2 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;
        inherit ami userData;

        modules = [ bitte.profiles.core ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;
        inherit ami userData;

        modules = [ bitte.profiles.core ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 300;
        inherit ami userData;

        modules = [
          bitte.profiles.monitoring
          ({config, ...}: let
            cfg = config.services.vault-backend;
          in {
            systemd.services.victoriametrics.serviceConfig.LimitNOFILE = 65535;
            services.monitoring.useVaultBackend = true;
            systemd.services.vault-backend.environment = lib.mkForce {
              VAULT_URL = "https://vault.service.consul:8200";
              VAULT_PREFIX = "vbk";
              LISTEN_ADDRESS = "${cfg.interface}:${toString cfg.port}";
              DEBUG = lib.mkIf cfg.debug "TRUE";
            };
          })
        ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https nfs-portmapper nfs;
        };
      };

      routing = {
        instanceType = "t3a.small";
        privateIP = "172.16.1.40";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;
        inherit ami userData;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ bitte.profiles.routing ./traefik.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http routing;
        };
      };

      hydra = {
        instanceType = "m5.4xlarge";
        privateIP = "172.16.0.52";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 600;
        inherit ami userData;

        modules = [
          ./cicero.nix
          bitte.profiles.hydra
          { nix.systemFeatures = [ "big-parallel" ]; }
          ./spongix.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh wireguard;
        };
      };

      storage-0 = {
        instanceType = "t3a.small";
        privateIP = "172.16.0.30";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 40;
        inherit ami userData;

        modules = [ bitte.profiles.storage ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-1 = {
        instanceType = "t3a.small";
        privateIP = "172.16.1.20";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 40;
        inherit ami userData;

        modules = [ bitte.profiles.storage ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-2 = {
        instanceType = "t3a.small";
        privateIP = "172.16.2.20";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 40;
        inherit ami userData;

        modules = [ bitte.profiles.storage ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };
    };
  };
}
