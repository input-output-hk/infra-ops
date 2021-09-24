{ pkgs, ... }: {
  fileSystems."/export/mafuyu" = {
    device = "/mnt/mafuyu";
    options = [ "bind" ];
  };

  services.nfs.server = let
    ips = [ "172.58.61.27" "107.77.198.19" "196.188.122.164" "185.66.51.109" "18.220.75.60" ];
    export = map (ip: "${ip}(rw,fsid=0,no_subtree_check)") ips;
    mafuyu = map (ip: "${ip}(rw,nohide,insecure,no_subtree_check)") ips;
  in {
    enable = true;
    exports = ''
      /export         ${builtins.concatStringsSep " " export}
      /export/mafuyu  ${builtins.concatStringsSep " " mafuyu}
    '';
  };


  networking.firewall.allowedTCPPorts = [ 111 2049 ];
}
