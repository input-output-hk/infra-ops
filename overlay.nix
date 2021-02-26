inputs: final: prev: {
  devShell = let
    cluster = "infra-production";
    domain = final.clusters.${cluster}.proto.config.cluster.domain;
  in prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster;
    AWS_PROFILE = "infra-ops";
    AWS_DEFAULT_REGION = final.clusters.${cluster}.proto.config.cluster.region;

    VAULT_ADDR = "https://vault.${domain}";
    NOMAD_ADDR = "https://nomad.${domain}";
    CONSUL_HTTP_ADDR = "https://consul.${domain}";
    NIX_USER_CONF_FILES = ./nix.conf;

    buildInputs = with final; [
      bitte
      terraform-with-plugins
      sops
      vault-bin
      openssl
      cfssl
      nixfmt
      awscli
      nomad
      consul
      consul-template
      direnv
      nixFlakes
      jq
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs ++ [ final.nixFlakes ];
    name = "devShell";
  };
}
