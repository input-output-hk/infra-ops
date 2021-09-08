{ pkgs, ... }: {
  fileSystems."/export/mafuyu" = {
    device = "/mnt/mafuyu";
    options = [ "bind" ];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export         196.188.117.34(rw,fsid=0,no_subtree_check) 185.66.51.109(rw,fsid=0,no_subtree_check)
      /export/mafuyu  196.188.117.34(rw,nohide,insecure,no_subtree_check) 185.66.51.109(rw,nohide,insecure,no_subtree_check)
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
}

# let
#   stateDir = "/var/lib/nfs";
#   ganeshaConfig = pkgs.writeText "ganesha.conf" ''
#     EXPORT {
#       Export_Id = 12345;
#       Path = ${stateDir}/ganesha/export/moe;
#       Pseudo = /moe;
#       Protocols = 3,4;
#       Access_Type = RW;
#       FSAL {
#         Name = VFS;
#       }
#     }
#
#     LOG {
#       Default_Log_Level = INFO;
#
#       Facility {
#         name = FILE;
#         destination = "${stateDir}/ganesha/ganesha.log";
#         enable = active;
#       }
#     }
#   '';
# in {
#   environment.etc."ganesha/ganesha.conf".source = ganeshaConfig;
#
#   systemd.services.nfs-ganesha = {
#     description = "Ganesha NFS Server";
#     after = [ "network.target" ];
#     wantedBy = [ "multi-user.target" ];
#     restartTriggers = [ ganeshaConfig ];
#
#     serviceConfig = {
#       ExecStartPre = pkgs.writeShellScript "nfs-ganehsa-pre" ''
#         mkdir -p ${stateDir}/ganesha/export/moe
#       '';
#       ExecStart =
#         "${pkgs.nfs-ganesha}/bin/ganesha.nfsd -F -p ${stateDir}/ganesha/ganesha.pid";
#       Restart = "on-failure";
#       RestartSec = "30s";
#       # DynamicUser = true;
#       # User = "ganesha";
#       StateDirectory = "nfs";
#       RuntimeDirectory = "nfs";
#     };
#   };
# }
