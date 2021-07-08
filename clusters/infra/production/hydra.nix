{ lib, config, pkgs, ... }: let
  hydraURL = "https://hydra.${config.cluster.domain}";
  inherit (config.cluster) domain kms;
  cfg = config.services.hydra;

  sopsEncrypt =
    "${pkgs.sops}/bin/sops --encrypt --input-type binary --kms '${kms}'";

in {
  # boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

  secrets.install = {
    # id_buildfarm = rec {
    #   inputType = "binary";
    #   outputType = "binary";
    #   source = config.secrets.encryptedRoot + "/id_buildfarm.json";
    #   target = "/etc/nix/id_buildfarm";
    #   script = ''
    #     chown hydra-queue-runner:hydra ${target}
    #     chmod 0400 ${target}
    #   '';
    # };

    nix-signing = rec {
      inputType = "binary";
      outputType = "binary";
      source = config.secrets.encryptedRoot + "/nix-secret-key-file";
      target = "/etc/nix/signing";
      script = ''
        chown hydra:hydra ${target}
        chmod 0440 ${target}
      '';
    };

    # github-token = rec {
    #   inputType = "json";
    #   outputType = "binary";
    #   source = config.secrets.encryptedRoot + "/github-token.json";
    #   target = "/run/keys/hydra-github-token";
    #   script = ''
    #     chown hydra:hydra ${target}
    #     chmod 0400 $_
    #     cat <<EOF > /etc/nix/netrc
    #     machine github.com
    #       login api
    #       password $(<${target})

    #     machine api.github.com
    #       login api
    #       password $(<${target})
    #     EOF
    #     chown root:hydra /etc/nix/netrc
    #     chmod 0440 $_
    #   '';
    # };

    # hydra-wireguard-pk = rec {
    #   inputType = "json";
    #   outputType = "binary";
    #   source = config.secrets.encryptedRoot + "/hydra-wireguard-pk.json";
    #   target = "/run/keys/hydra-wireguard-pk";
    # };
  };

  # secrets.generate.id_buildfarm = ''
  #   if [[ ! -s encrypted/id_buildfarm.json ]]; then
  #     ${sopsEncrypt} secrets/id_buildfarm \
  #       > encrypted/id_buildfarm.json

  #     ${pkgs.git}/bin/git add encrypted/id_buildfarm.json
  #   fi
  # '';

  # secrets.generate.github-token = ''
  #   if [[ ! -s encrypted/github-token.json ]]; then
  #     ${sopsEncrypt} secrets/github-token \
  #       > encrypted/github-token.json

  #     ${pkgs.git}/bin/git add encrypted/github-token.json
  #   fi
  # '';

  # secrets.generate.hydra-wireguard-pk = ''
  #   if [[ ! -s encrypted/hydra-wireguard-pk.json ]]; then
  #     ${sopsEncrypt} secrets/hydra-wireguard-pk \
  #       > encrypted/hydra-wireguard-pk.json

  #     ${pkgs.git}/bin/git add encrypted/hydra-wireguard-pk.json
  #   fi
  # '';

  users.users.hydra.extraGroups = [ "keys" ];

  programs.ssh = {
    extraConfig = ''
      Host mac-mini-1
        Hostname 192.168.20.21
        Port 2200
      Host mac-mini-2
        Hostname 192.168.20.22
        Port 2200
    '';

    # knownHosts = {
    #   github = {
    #     hostNames = [ "github.com" ];
    #     publicKeyFile = ./github.pub;
    #   };
    #   packet-1 = {
    #     hostNames = [ "mantis-slave-packet-1.aws.iohkdev.io" ];
    #     publicKeyFile = ./packet-1.pub;
    #   };
    #   packet-2 = {
    #     hostNames = [ "mantis-slave-packet-2.aws.iohkdev.io" ];
    #     publicKeyFile = ./packet-2.pub;
    #   };
    #   mac-mini-1 = {
    #     hostNames = [ "[192.168.20.21]:2200" ];
    #     publicKeyFile = ./mac-mini-1.pub;
    #   };
    #   mac-mini-2 = {
    #     hostNames = [ "[192.168.20.22]:2200" ];
    #     publicKeyFile = ./mac-mini-2.pub;
    #   };
    # };
  };

  networking = {
    firewall.allowedTCPPorts = [ cfg.port ];
    firewall.allowedUDPPorts = [ 17777 ];

    # wireguard.interfaces.wg0 = {
    #   ips            = [ "192.168.142.3/32" ];
    #   listenPort     = 17777;
    #   privateKeyFile = "/run/keys/hydra-wireguard-pk";

    #   peers = let
    #     mac-mini-1 = {
    #       allowedIPs = [ "192.168.20.21/32" ];
    #       publicKey = "nvKCarVUXdO0WtoDsEjTzU+bX0bwWYHJAM2Y3XhO0Ao=";
    #       persistentKeepalive = 25;
    #     };
    #     mac-mini-2 = {
    #       allowedIPs = [ "192.168.20.22/32" ];
    #       publicKey = "VcOEVp/0EG4luwL2bMmvGvlDNDbCzk7Vkazd3RRl51w=";
    #       persistentKeepalive = 25;
    #     };
    #   in [ mac-mini-1 mac-mini-2 ];
    # };
  };

  nix = {
    # allowedUris = [
    #   "https://github.com/input-output-hk"
    #   "https://github.com/nixos"
    # ];
    # buildMachines = with lib; let
    #   common = {
    #     speedFactor       = 1;
    #     maxJobs           = 8;
        # sshKey            = "/etc/nix/id_buildfarm";
      # };

      # packet = flip genList 2 (i: common // {
      #   hostName          = "mantis-slave-packet-${toString (i + 1)}.aws.iohkdev.io";
      #   supportedFeatures = [ "benchmark" "kvm" "nixos-test" ];
      #   sshUser           = "root";
      #   system            = "x86_64-linux";
      # });

      # darwin = flip genList 2 (i: common // {
      #   hostName = "mac-mini-${toString (i + 1)}";
      #   sshUser = "builder";
      #   system = "x86_64-darwin";
      #   supportedFeatures = [ "big-parallel" ];
      # });
    # in darwin;
    # in packet ++ darwin;
  };

  services.hydra = {
    inherit hydraURL;

    buildMachinesFiles = [
      "/etc/nix/machines"
      (pkgs.writeText "hydra-localhost" ''
        localhost x86_64-linux,builtin - 4 10 benchmark,big-parallel
      '')
    ];

    enable = true;
    port = 3001;
    logo = "${./iohk-logo.png}";
    useSubstitutes     = true;
    # listenHost = "127.0.0.1";
    # TODO enable notifications
    #notifications.enable = true;
    notificationSender = "hydra@${domain}";
    # TODO get rid of secrets in config. this gets into the store which is bad.
    #      use environment variable to override the location of the config file
    #      and place there a concatenation of the generated config and a
    #      fragment with all the secrets
    extraConfig = ''
      binary_cache_secret_key_file = /etc/nix/signing
      store-uri = file:///nix/store?secret-key=/etc/nix/signing
      enable_google_login = 1
      google_client_id = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com

      <github_authorization>
      input-output-hk = Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      </github_authorization>
    '';

    users = {
      "shay.bergmann@iohk.io" = {
        fullName = "Shay Bergmann";
        roles = [ "admin" ];
      };

      "michael.fellinger@iohk.io" = {
        fullName = "Michael Fellinger";
        roles = [ "admin" ];
      };

      "jonathan.ringer@iohk.io" = {
        fullName = "Jonathan Ringer";
        roles = [ "admin" ];
      };

      "tim.deherrera@iohk.io" = {
        fullName = "Timothy DeHerrera";
        roles = [ "admin" ];
      };
    };

    projects = let
      declvalue = "https://github.com/input-output-hk/mantis-ops master";
      owner = "tim.deherrera@iohk.io";
    in {
      mantis = {
        inherit owner declvalue;
        displayName = "Mantis Node";
        description = "A Scala based client for Ethereum-like Blockchains.";
      };

      mantis-explorer = {
        inherit owner declvalue;
        displayName = "Mantis Explorer";
        description = "Browse the Mantis Blockchain";
      };
    };
  };
}
