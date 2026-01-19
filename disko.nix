{
  disko.devices = {
    disk.vda = {
      type = "disk";
      device = "/dev/vda"; # VM disk
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          crypt = {
            # LUKS partition
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # keyFile = "/tmp/secret.key";  # Optional for install
              content = {
                type = "table"; # No further partitions needed
                format = "none"; # ZFS on whole LUKS mapper
              };
            };
          };
        };
      };
    };
    zpool.rpool = {
      type = "zpool";
      options.ashift = "12";
      rootFsOptions = {
        compression = "zstd";
        normalization = "none";
        acltype = "posixacl";
        xattr = "sa";
        dnodesize = "auto";
        mountpoint = "none";
      };
      datasets = {
        "local/root" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          postCreate = ''
            zfs snapshot rpool/local/root@blank
          '';
        };
        "local/nix" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
        };
        "safe/persist" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
        };
        "safe/home" = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
