# Am I ROOT
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
# --- Post-flight checks -------------------------------------------------------
echo -e "${GREEN}=== Post-flight checks ===${NC}"

fail() { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $*" >&2; }

# 1) LUKS mapping exists / is active
if ! cryptsetup status cryptroot >/dev/null 2>&1; then
  fail "cryptroot mapping not active (cryptsetup status cryptroot failed)"
fi

# 2) ZFS pool exists and is ONLINE
pool_state="$(zpool status rpool 2>/dev/null | awk -F': ' '/^ state:/ {print $2; exit}')"
[ -n "$pool_state" ] || fail "Could not read zpool state for rpool"

if [ "$pool_state" != "ONLINE" ]; then
  zpool status rpool >&2 || true
  fail "rpool state is '$pool_state' (expected ONLINE)"
fi

# 3) Required datasets exist
for ds in \
  rpool/local/root \
  rpool/local/nix \
  rpool/safe/home \
  rpool/safe/persist
do
  zfs list -H -o name "$ds" >/dev/null 2>&1 || fail "Missing dataset: $ds"
done

# 4) Impermanence base snapshot exists
# (zfs supports listing snapshots with -t snapshot) [web:107]
zfs list -t snapshot -H -o name rpool/local/root 2>/dev/null | grep -qx 'rpool/local/root@blank' \
  || fail "Missing snapshot: rpool/local/root@blank"

# 5) Mountpoints are actually mounted where expected
# findmnt can search for a filesystem by a target path (-T/--target). [web:106]
findmnt -T /mnt        >/dev/null 2>&1 || fail "/mnt is not a mountpoint"
findmnt -T /mnt/boot   >/dev/null 2>&1 || fail "/mnt/boot is not a mountpoint"
findmnt -T /mnt/nix    >/dev/null 2>&1 || fail "/mnt/nix is not a mountpoint"
findmnt -T /mnt/home   >/dev/null 2>&1 || fail "/mnt/home is not a mountpoint"
findmnt -T /mnt/persist >/dev/null 2>&1 || fail "/mnt/persist is not a mountpoint"

# 6) Show a compact status summary (useful when you paste logs)
echo
if [ -n "${DISK:-}" ]; then
  echo "--- lsblk -f ${DISK} ---"
  lsblk -f "$DISK"
else
  echo "--- lsblk -f ---"
  lsblk -f
fi

echo
echo "--- zpool status rpool ---"
zpool status rpool

echo
echo "--- zfs list ---"
zfs list

echo -e "${GREEN}Generating NixOS config in /mnt/etc/nixos...${NC}"
nixos-generate-config --root /mnt

echo -e "${GREEN}Config generated:${NC}"
ls -l /mnt/etc/nixos || true


echo
echo -e "${GREEN}All checks passed.${NC}"
# ---------------------------------------------------------------------------
# Run these commands after the script finishes but before you reboot

# Create the directory on the persistent dataset
mkdir -p /mnt/persist/etc/nixos

# Move the generated config files to safe storage
mv /mnt/etc/nixos/* /mnt/persist/etc/nixos/

# Remove the now-empty directory on the ephemeral root
rmdir /mnt/etc/nixos

# Link the persistent config back to the system location
# (The rollback will wipe the link, but we can recreate it or use /persist in the config)
# Ideally, you just want the files safe first.

