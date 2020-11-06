{ lib, buildLayeredImage, mkEnv, coreutils, writeShellScript }:
let
  entrypoint = writeShellScript "env" ''
    env

    while true; do
      sleep 1
    done
  '';
in {
  env = buildLayeredImage {
    name = "docker.infra.aws.iohk.io/env";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv { PATH = lib.makeBinPath [ coreutils ]; };
    };
  };
}
