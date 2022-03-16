{ self, lib, pkgs, config, ... }:
let inherit (config.cluster) domain;
in {
  services.consul.ui = true;

  services.traefik = {
    enable = true;
    acmeDnsCertMgr = false;
    useVaultBackend = true;
  };

  /* services.oauth2_proxy.provider = lib.mkForce "github";
     services.oauth2_proxy.keyFile = lib.mkForce "/run/keys/github-oauth-secrets";
     services.oauth2_proxy.extraConfig.skip-provider-button = "true";
     services.oauth2_proxy.extraConfig.upstream = "static://202";
     services.oauth2_proxy.extraConfig.github-user =
       builtins.concatStringsSep "," [ "manveru" "dermetfan" "biandratti" ];
     services.oauth2_proxy.extraConfig.github-org = "input-output-hk";
     services.oauth2_proxy.email.domains = lib.mkForce [ "*" ];
     services.oauth2_proxy.scope = builtins.concatStringsSep "," [
       "user:email"
       "read:public_key"
       "read:org"
       "repo"
     ];
     # services.oauth2_proxy.extraConfig.set-authorization-header=true;
     services.oauth2_proxy.extraConfig.pass-access-token = true;

     secrets.install.github-oauth.script = ''
       export PATH="${lib.makeBinPath (with pkgs; [ sops coreutils ])}"
       dest=/run/keys/github-oauth-secrets
       sops -d ${config.secrets.encryptedRoot + /github-oauth-secrets} > "$dest"
       chown root:keys "$dest"
       chmod g+r "$dest"
     '';
  */
}
