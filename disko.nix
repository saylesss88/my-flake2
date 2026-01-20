{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G"; # Matches your manual setup (512M is fine too, but manual used 1G)
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            crypt = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = true;
                  # keyFile = "/tmp/secret.key"; # Optional for automated install
                };
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          normalization = "none";
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto";
          mountpoint = "none";
          canmount = "off";
        };
        datasets = {
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/"; # Disko generates fileSystems."/" from this
            options.mountpoint = "legacy";
            postCreateHook = "zfs snapshot rpool/local/root@blank";
          };
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
            options."com.sun:auto-snapshot" = "true"; # Optional
          };
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
