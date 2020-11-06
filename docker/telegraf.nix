{ buildLayeredImage, telegraf }: {
  telegraf = buildLayeredImage {
    name = "docker.infra.aws.iohk.io/telegraf";
    config.Entrypoint = [ "${telegraf}/bin/telegraf" ];
  };
}
