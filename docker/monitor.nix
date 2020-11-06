{ buildLayeredImage, mkEnv, jormungandr-monitor, cacert, coreutils
, bashInteractive, busybox, curl, lsof }: {
  monitor = buildLayeredImage {
    name = "docker.infra.aws.iohk.io/monitor";
    contents = [ coreutils bashInteractive busybox curl lsof ];
    config = {
      Entrypoint = [ jormungandr-monitor ];

      Env = mkEnv { SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt"; };
    };
  };
}
