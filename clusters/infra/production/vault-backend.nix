{ lib, config, pkgs, ... }:
let cfg = config.services.vault-backend;
in {
  options = {
    services.vault-backend = {
      enable = lib.mkEnableOption "Enable the Terraform Vault Backend";
    };
  };

  config = {
    systemd.services.vault-backend = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        VAULT_URL =
          "https://${config.cluster.instances.core-1.privateIP}:8200"; # (default http://localhost:8200) the URL of the Vault server
        VAULT_PREFIX = "vbk"; # the prefix used when storing the secrets
        LISTEN_ADDRESS =
          "127.0.0.1:8080"; # (default 0.0.0.0:8080) the listening address and port
        # TLS_CRT = "/var/lib/vault-backend/cert.pem"; # to set the path of the TLS certificate file
        # TLS_KEY = "/var/lib/vault-backend/cert-key.pem"; # to set the path of the TLS key file
        DEBUG = "true"; # to enable verbose logging
      };

      serviceConfig = let
        execStartPre = pkgs.writeShellScriptBin "vault-backend-pre" ''
          set -exuo pipefail
          export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"

          cp /etc/ssl/certs/{cert,cert-key}.pem .
          chown --reference . --recursive .
        '';
      in {
        ExecStartPre = "!${execStartPre}/bin/vault-backend-pre";
        ExecStart = "${pkgs.vault-backend}/bin/vault-backend";

        DynamicUser = true;
        Group = "vault-backend";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = "read-only";
        ProtectSystem = "full";
        Restart = "on-failure";
        RestartSec = "10s";
        StartLimitBurst = 3;
        StateDirectory = "vault-backend";
        TimeoutStopSec = "30s";
        User = "vault-backend";
        WorkingDirectory = "/var/lib/vault-backend";
      };
    };

    services.ingress-config = {
      extraGlobalConfig = ''
        debug
      '';

      extraHttpsFrontendConfig = ''
        acl is_vbk hdr(host) -i vbk.${config.cluster.domain}
        use_backend vbk if is_vbk
      '';

      extraConfig = ''
        {{- range services -}}
          {{- if .Tags | contains "ingress" -}}
            {{- range service .Name -}}
              {{- if .ServiceMeta.IngressServer }}

        backend {{ .ID }}
          mode {{ or .ServiceMeta.IngressMode "http" }}
          default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
          {{ .ServiceMeta.IngressBackendExtra | trimSpace | indent 2 }}
          server {{.ID}} {{ .ServiceMeta.IngressServer }}

                {{- if (and .ServiceMeta.IngressBind (ne .ServiceMeta.IngressBind "*:443") ) }}

        frontend {{ .ID }}
          bind {{ .ServiceMeta.IngressBind }}
          mode {{ or .ServiceMeta.IngressMode "http" }}
          {{ .ServiceMeta.IngressFrontendExtra | trimSpace | indent 2 }}
          default_backend {{ .ID }}
                {{- end }}
              {{- end -}}
            {{- end -}}
          {{- end -}}
        {{- end }}

        backend vbk
          mode http
          server ipv4 127.0.0.1:8080
      '';
    };
  };
}
