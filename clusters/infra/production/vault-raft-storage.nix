{ lib, config, ... }: {
  services.vault.storage.raft = let
    vcfg = config.services.vault.listener.tcp;
    instances =
      lib.filterAttrs (k: v: k != "monitoring") config.cluster.instances;
  in {
    retryJoin = lib.mapAttrsToList (_: v: {
      leaderApiAddr = "https://${v.privateIP}:8200";
      leaderCaCertFile = vcfg.tlsCertFile;
      leaderClientCertFile = vcfg.tlsCertFile;
      leaderClientKeyFile = vcfg.tlsKeyFile;
    }) instances;
  };
}
