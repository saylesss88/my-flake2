#!/usr/bin/env bash

# ZFS on LUKS + Impermanence Setup Script
# Based on instructions by saylesss88

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NixOS ZFS+LUKS+Impermanence Setup ===${NC}"
echo -e "${YELLOW}WARNING: This script will DESTROY ALL DATA on the selected disk.${NC}"
echo

# 1. Select Disk
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -v "rom"
echo
read -p "Enter the target disk (e.g., vda, nvme0n1): " DISK_NAME

# Sanitize input (remove /dev/ prefix if typed)
DISK_NAME=${DISK_NAME#/dev/}
DISK="/dev/${DISK_NAME}"

if [ ! -b "$DISK" ]; then
    echo -e "${RED}Error: Device $DISK not found.${NC}"
    exit 1
fi

echo -e "${YELLOW}You have selected: $DISK${NC}"
read -p "Are you absolutely sure you want to proceed? (yes/NO): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborting."
    exit 1
fi

# 2. Partitioning
echo -e "${GREEN}[1/6] Partitioning disk...${NC}"
# Wipe signatures
wipefs -a "$DISK"

# Create partitions using sgdisk for automation (easier than cfdisk scripting)
# Part 1: 1G EFI System Partition (Hex Code EF00)
# Part 2: Remaining space for LUKS/ZFS (Hex Code 8300 - Linux Filesystem)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux LUKS" "$DISK"

# Determine partition names (handle nvme naming convention p1 vs 1)
if [[ "$DISK" =~ "nvme" ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

# 3. Format EFI
echo -e "${GREEN}[2/6] Formatting EFI partition...${NC}"
mkfs.fat -F32 -n EFI "$PART1"

# 4. Setup LUKS
echo -e "${GREEN}[3/6] Setting up LUKS encryption...${NC}"
echo -e "${YELLOW}Enter password for LUKS encryption:${NC}"
cryptsetup luksFormat "$PART2"
echo -e "${YELLOW}Opening LUKS container...${NC}"
cryptsetup open "$PART2" cryptroot

# 5. Create ZPool
echo -e "${GREEN}[4/6] Creating ZFS Pool 'rpool'...${NC}"
zpool create \
  -f \
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

# 6. Create Datasets
echo -e "${GREEN}[5/6] Creating ZFS datasets...${NC}"

# Root (ephemeral)
zfs create -p -o canmount=noauto -o mountpoint=legacy rpool/local/root
zfs snapshot rpool/local/root@blank

# Nix store
zfs create -p -o mountpoint=legacy rpool/local/nix

# Persistent data
zfs create -p -o mountpoint=legacy rpool/safe/home
zfs create -p -o mountpoint=legacy rpool/safe/persist

# 7. Mounting
echo -e "${GREEN}[6/6] Mounting filesystems...${NC}"
# Mount root
mount -t zfs rpool/local/root /mnt

# Create directories
mkdir -p /mnt/{nix,home,persist,boot}

# Mount Boot
mount -t vfat -o umask=0077 "$PART1" /mnt/boot

# Mount datasets
mount -t zfs rpool/local/nix /mnt/nix
mount -t zfs rpool/safe/home /mnt/home
mount -t zfs rpool/safe/persist /mnt/persist

# Capture UUID for configuration
LUKS_UUID=$(blkid -s UUID -o value "$PART2")

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "LUKS UUID for configuration.nix: ${YELLOW}${LUKS_UUID}${NC}"
echo
echo "Next steps:"
echo "1. Generate config: sudo nixos-generate-config --root /mnt"
echo "2. Edit configuration.nix and add:"
echo "   boot.initrd.luks.devices.\"cryptroot\".device = \"/dev/disk/by-uuid/${LUKS_UUID}\";"
echo

