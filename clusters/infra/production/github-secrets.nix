{ config, pkgs, ... }:
let
  inherit (config.cluster) domain kms;

  sopsEncrypt =
    "${pkgs.sops}/bin/sops --encrypt --input-type binary --kms '${kms}'";
in {
  secrets.install.github-etc-nix-netrc = {
    inputType = "binary";
    outputType = "binary";
    source = config.secrets.encryptedRoot + "/netrc";
    target = "/etc/nix/netrc";
    script = ''
      chmod 0600 /etc/nix/netrc
    '';
  };

  secrets.install.github-root-netrc = {
    inputType = "binary";
    outputType = "binary";
    source = config.secrets.encryptedRoot + "/netrc";
    target = "/root/.netrc";
    script = ''
      chmod 0600 /root/.netrc
    '';
  };

  secrets.install.github-var-lib-nomad = {
    inputType = "binary";
    outputType = "binary";
    source = config.secrets.encryptedRoot + "/netrc";
    target = "/var/lib/nomad/.netrc";
    script = ''
      chmod 0600 /var/lib/nomad/.netrc
    '';
  };

  secrets.install.github-ssh = rec {
    inputType = "json";
    outputType = "binary";
    source = config.secrets.encryptedRoot + "/github-ssh.json";
    target = "/root/.ssh/id_ed25519";
    script = ''
      chmod 0600 ${target}
    '';
  };

  services.openssh.knownHosts = {
    github = {
      hostNames = [ "github.com" "140.82.121.4" ];
      publicKey = ''
        ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
      '';
    };

    apiGithub = {
      hostNames = [ "api.github.com" "140.82.121.3" ];
      publicKey = ''
        ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
      '';
    };
  };

}
