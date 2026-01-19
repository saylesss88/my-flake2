{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    # ./hardware-configuration.nix
    # ./impermanence.nix
  ];
  #============================#
  #      Lanzaboote (requires nixpkgs 25.05)
  # ===========================#
  # nixpkgs.overlays = [
  #  (final: prev: {
  #     lanzaboote = (inputs.nixpkgs-stable.legacyPackages.${pkgs.system}.lanzaboote or prev.lanzaboote)
  #  })
  # ];

  # environment.systemPackages = [ pkgs.sbctl ];

  # boot.loader.systemd-boot.enable = lib.mkForce false;

  # boot.lanzaboote = {
  #   enable = true;
  #   pkiBundle = "/var/lib/sbctl";
  # };
  # =================================#

  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
      editor = false;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/"; # Critical for VMs
  # Not needed with LUKS
  boot.zfs.requestEncryptionCredentials = false;
  # systemd handles mounting
  systemd.services.zfs-mount.enable = false;

  services.zfs = {
    autoScrub.enable = true;
    # periodically runs `zpool trim`
    trim.enable = true;
    # autoSnapshot = true;
  };

  boot.initrd.luks.devices = {
    cryptroot = {
      # replace uuid# with output of UUID # from `sudo blkid /dev/vda2`
      device = "/dev/disk/by-uuid/uuid#";
      allowDiscards = true;
      preLVM = true;
    };
  };

  # ------------------------------------------------------------------
  # Roll-back root to blank snapshot on **every** boot
  # ------------------------------------------------------------------
  # Uncomment after first reboot
  # boot.initrd.postMountCommands = lib.mkAfter ''
  #   zfs rollback -r rpool/local/root@blank
  # '';

  # ------------------------------------------------------------------
  # 5. Basic system (root password, serial console for VM)
  # ------------------------------------------------------------------
  # Unique 8-hex hostId (run once in live ISO: head -c4 /dev/urandom | xxd -p)
  networking.hostId = "a1b2c3d4"; # <<<--- replace with your own value

  users.users.root.initialPassword = "changeme"; # change after first login

  boot.kernelParams = [ "console=tty1" ];

  # ------------------------------------------------------------------
  #  Users
  # ------------------------------------------------------------------

  users.mutableUsers = false;

  # Change `your-user`
  users.users.your-user = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    group = "your-user";
    # :r /tmp/pass.txt:
    initialHashedPassword = "";
  };

  # This enables `chown -R your-user:your-user`
  users.groups.your-user = { };

  # ------------------------------------------------------------------
  #  (Optional) Helpful for recovery situations
  # ------------------------------------------------------------------
  # users.users.admin = {
  #  isNormalUser = true;
  #  description = "admin account";
  #  extraGroups = [ "wheel" ];
  #  group = "admin";
  # initialHashedPassword = "Output of `:r /tmp/pass.txt`";
  # };

  # users.groups.admin = { };
  # ------------------------------------------------------------------

  # ------------------------------------------------------------------
  # (Optional) Enable SSH for post-install configuration
  # ------------------------------------------------------------------
  # services.openssh = {
  #  enable = true;
  #  settings.PermitRootLogin = "yes";
  #};

  # ------------------------------------------------------------------
  # Mark /persist as needed for boot
  # ------------------------------------------------------------------
  fileSystems."/persist".neededForBoot = true;
}
