inputs: final: prev: {
  devShell = let
    cluster = final.clusters.infra-production.proto.config.cluster;
    inherit (cluster) domain;
  in prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster.name;
    AWS_PROFILE = "infra-ops";
    AWS_DEFAULT_REGION = cluster.region;
    TERRAFORM_ORGANIZATION = cluster.terraformOrganization;
    NOMAD_NAMESPACE = "infra-default";

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
      jq
      go
      goimports
      gopls
      gocode
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs ++ [ final.nixFlakes ];
    name = "devShell";
  };
}
