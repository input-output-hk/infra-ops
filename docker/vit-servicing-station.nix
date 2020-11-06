{ buildLayeredImage, vit-servicing-station }: {
  vit-servicing-station = buildLayeredImage {
    name = "docker.infra.aws.iohk.io/vit-servicing-station";
    config.Entrypoint =
      [ "${vit-servicing-station}/bin/vit-servicing-station-server" ];
  };
}
