# ZFS on LUKS + Impermanence Guide

## SSH in from the Host

1. Set a password for the `nixos` user:

```bash
sudo passwd nixos
```

2. Find the IP address:

```bash
ip a
```

3. SSH in from your host or another machine:

```bash
ssh nixos@192.168.1.x
```

---

## Scripted ZFS on LUKS

- Inspect
  [install.sh](https://github.com/saylesss88/my-flake2/blob/main/install.sh)
  HERE.

If you use the script included in the repo, you can move straight to setting up
your `configuration.nix`.

```bash
git clone https://github.com/saylesss88/my-flake2.git
cd my-flake2
sudo chmod +x install.sh test.sh
sudo ./install.sh
```

When the script finishes, run `test.sh` to ensure everything is correct.

- Inspect [test.sh](https://github.com/saylesss88/my-flake2/blob/main/test.sh)
  HERE.

```bash
sudo ./test.sh
```

Skip the next section of the guide and add the requirements to your
`configuration.nix`.

## Setup LUKS & Create your zpool

When creating the VM, before clicking "Finish", check the "Customize
configuration before install" box and choose EFI Firmware > BIOS. **You will
waste a bunch of time if you forget to do this**!

- I used `OVMF_CODE.fd` in my testing.

- OR choose `/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2` and follow the
  [Secure Boot in a libvirt VM Guide](https://saylesss88.github.io/nix/secureboot_libvirt.html)

**Format your disk**

1. Partition & Format

```bash
sudo cfdisk /dev/vda
sudo mkfs.fat -F32 /dev/vda1
```

2. Setup LUKS

```bash
sudo cryptsetup luksFormat /dev/vda2
sudo cryptsetup open /dev/vda2 cryptroot
```

3. Create zpool (Edited 2026-01-18 normalization=none)

```bash
sudo zpool create \
  -o ashift=12 \
  -o autotrim=on \
  -O acltype=posixacl \
  -O canmount=off \
  -O compression=zstd \
  -O normalization=none \
  -O relatime=on \
  -O xattr=sa \
  -O dnodesize=auto \
  -O mountpoint=none \
  rpool /dev/mapper/cryptroot
```

4. Dataset Creation

```bash
# root (ephemeral)
sudo zfs create -p -o canmount=noauto -o mountpoint=legacy rpool/local/root
sudo zfs snapshot rpool/local/root@blank

# nix store
sudo zfs create -p -o mountpoint=legacy rpool/local/nix

# persistent data
sudo zfs create -p -o mountpoint=legacy rpool/safe/home
sudo zfs create -p -o mountpoint=legacy rpool/safe/persist
```

- `mountpoint=legacy` means that systemd will take care of the mounting

5. Mounting

```bash
# 1. Mount root first
sudo mount -t zfs rpool/local/root /mnt

# 2. Create directories
sudo mkdir -p /mnt/{nix,home,persist,boot}

# 3. Mount ESP directly to /boot (simpler and safer for systemd-boot)
sudo mount -t vfat -o umask=0077 /dev/vda1 /mnt/boot

# 4. Mount other ZFS datasets
sudo mount -t zfs rpool/local/nix /mnt/nix
sudo mount -t zfs rpool/safe/home /mnt/home
sudo mount -t zfs rpool/safe/persist /mnt/persist
```

6. Configuration Prep

```bash
sudo nixos-generate-config --root /mnt
```

```bash
export NIX_CONFIG='experimental-features = nix-command flakes'
nix-shell -p helix
```

```bash
head -c4 /dev/urandom | xxd -p > /tmp/rand.txt
mkpasswd --method=yescrypt > /tmp/pass.txt
sudo blkid /dev/vda2
# Copy the uuid
```

## Using the flake from this repo

1. If you have an existing flake, you can use the structure to build out this
   one, or just move the necessary parts from this one to yours.

The necessary parts:

```nix
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

  # ------------------------------------------------------------------
  # 2. ZFS support see: https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/index.html
  # ------------------------------------------------------------------
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";       # Critical for VMs
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

  # ------------------------------------------------------------------
  # 3. LUKS
  # ------------------------------------------------------------------
   boot.initrd.luks.devices = {
     cryptroot = {
    # replace uuid# with output of UUID # from `sudo blkid /dev/vda2`
       device = "/dev/disk/by-uuid/uuid#";
       allowDiscards = true;
       preLVM = true;
     };
   };

  # ------------------------------------------------------------------
  # 4. Roll-back root to blank snapshot on **every** boot
  # ------------------------------------------------------------------
 # Uncomment after first reboot
 # boot.initrd.postMountCommands = lib.mkAfter ''
 #   zfs rollback -r rpool/local/root@blank
 # '';

  # ------------------------------------------------------------------
  # 5. Basic system (root password, serial console for VM)
  # ------------------------------------------------------------------
  # Unique 8-hex hostId (run once in live ISO: head -c4 /dev/urandom | xxd -p)
  networking.hostId = "a1b2c3d4";    # <<<--- replace with your own value

  users.users.root.initialPassword = "changeme";   # change after first login

  boot.kernelParams = [ "console=tty1" ];

```
