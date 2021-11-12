{ pkgs, lib, self, ... }: {
  services.nomad.client.chroot_env =
    lib.mkForce { "/etc/passwd" = "/etc/passwd"; };

  services.nomad.pluginDir =
    "${self.inputs.nomad-driver-nix.defaultPackage.x86_64-linux}/bin";

  systemd.services.nomad-follower = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nomad.service" ];

    environment = {
      VAULT_ADDR = "http://127.0.0.1:8200";
      NOMAD_ADDR = "https://127.0.0.1:4646";
    };

    path = with pkgs; [ nomad-follower vector vault-bin nomad ];

    script = ''
      set -euo pipefail

      if [ -s nomad-follower.token ]; then
        NOMAD_TOKEN="$(< nomad-follower.token)"
        export NOMAD_TOKEN
      fi

      if nomad acl token self &> /dev/null; then
        echo "using existing token"
      else
        VAULT_TOKEN="$(< /run/keys/vault-token)"
        export VAULT_TOKEN

        NOMAD_TOKEN="$(vault read -field=secret_id nomad/creds/nomad-follower)"
        export NOMAD_TOKEN
        echo "$NOMAD_TOKEN" > nomad-follower.token
      fi

      exec nomad-follower \
        --state /var/lib/nomad-follower \
        --alloc /var/lib/nomad/alloc/%s/alloc \
        --loki-url http://monitoring:3100 \
        --namespace cicero
    '';

    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
      StateDirectory = "nomad-follower";
      WorkingDirectory = "/var/lib/nomad-follower";
    };
  };
}
