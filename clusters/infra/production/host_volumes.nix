{ ... }: {
  services.nomad.client = {
    host_volume = [{
      infra-ceph = {
        path = "/var/lib/seaweedfs-mount/nomad/infra-ceph";
        read_only = false;
      };
    }];
  };
}
