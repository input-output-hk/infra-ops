{ inputs, config, pkgs, lib, ... }:
let
  secret-key = "/etc/nix/secret-key";
  public-key =
    builtins.readFile (config.secrets.encryptedRoot + "/nix-public-key-file");
in {
  imports = [ inputs.nix-cache-proxy.nixosModules.nix-cache-proxy ];

  systemd.tmpfiles.rules = [ "d /mnt/gv0/nix-cache-proxy 1777 root root -" ];

  services.nix-cache-proxy = {
    enable = true;
    # awsBucketName =
    # awsBucketRegion =
    # awsProfile =
    cacheDir = "/mnt/gv0/nix-cache-proxy";
    host = "";
    port = 7745;
    secretKeyFiles = { infra-production = secret-key; };
    substituters = [ "https://cache.nixos.org" "https://hydra.iohk.io" ];
    trustedPublicKeys = [
      public-key
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };

  nix = {
    extraOptions = let
      post-build-hook = pkgs.writeShellScript "nix-cache-proxy" ''
        set -euf
        export IFS=' '
        echo "Uploading to cache: $OUT_PATHS"
        exec nix copy --to 'http://${config.cluster.coreNodes.storage-0.privateIP}:7745/cache' $OUT_PATHS
      '';
    in ''
      http2 = true
      gc-keep-derivations = true
      keep-outputs = true
      min-free-check-interval = 300
      log-lines = 100
      warn-dirty = false
      fallback = true
      post-build-hook = ${post-build-hook}
      secret-key-files = ${secret-key}
    '';

    binaryCaches = lib.mkForce [ "http://storage-0:7745" ];
    binaryCachePublicKeys = [ public-key ];
  };

  secrets.install.nix-secret-key = {
    inputType = "binary";
    outputType = "binary";
    source = config.secrets.encryptedRoot + "/nix-secret-key-file";
    target = "/etc/nix/secret-key";
    script = ''
      chmod 0600 /etc/nix/secret-key
    '';
  };
}
