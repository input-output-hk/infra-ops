{ config, ... }: {
  secrets.encryptedRoot = builtins.path {
    path = ../../../encrypted;
    name = "encrypted";
  };
  environment.extraInit = ''
    # ${config.secrets.encryptedRoot}
  '';
}
