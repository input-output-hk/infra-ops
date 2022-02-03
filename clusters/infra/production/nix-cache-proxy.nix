{ inputs, config, pkgs, lib, ... }: {
  imports = [ inputs.nix-cache-proxy.nixosModules.nix-cache-proxy ];

  services.nix-cache-proxy = {
    enable = true;
    # awsBucketName =
    # awsBucketRegion =
    # awsProfile =
    # cacheDir =
    # host =
    # port =
    # secretKeyFiles =
    # substituters =
    # trustedPublicKeys =
    # (builtins.readFile (config.secrets.encryptedRoot + /nix-public-key-file))
  };

  nix = {
    extraOptions = let
      post-build-hook = pkgs.writeShellScript "nix-cache-proxy" ''
        set -euf
        export IFS=' '
        echo "Uploading to cache: $OUT_PATHS"
        exec nix copy --to 'http://127.0.0.1:7745/cache' $OUT_PATHS
      '';
    in ''
      http2 = true
      gc-keep-derivations = true
      keep-outputs = true
      experimental-features = nix-command flakes recursive-nix
      min-free-check-interval = 300
      log-lines = 100
      warn-dirty = false
      fallback = true
      post-build-hook = ${post-build-hook}
      secret-key-files = ${config.age.secrets.nix-private-key.path}
    '';

    binaryCaches = lib.mkForce [ "http://storage-0:7745" ];
    binaryCachePublicKeys = [
      (builtins.readFile (config.secrets.encryptedRoot + /nix-public-key-file))
    ];
  };
}
