{ inputs, lib, ... }:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    # 1. Wait for LUKS
    udevadm settle
    # 2. Force the pool into the "garage"
    zpool import -f -N rpool
    # 3. Clean the slate
    zfs rollback -r rpool/local/root@blank
    # 4. Give the pool back to the system
    zpool export rpool
  '';

  environment.persistence."/persist" = {
    directories = [
      # "/var/lib/sbctl"
      "/etc/NetworkManager/system-connections" # This is where Wi-Fi/Ethernet profiles live
      "/var/lib/bluetooth" # While you're at it, keep your Bluetooth pairs
      "/var/lib/nixos" # Keeps track of UID/GIDs
      "/var/lib/systemd/coredump"
    ];
    # files = [
    #   "/etc/machine-id"
    # ];
  };
}
