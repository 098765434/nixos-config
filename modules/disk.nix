# Declarative disk layout (disko): GPT + ESP + LUKS2 + btrfs subvolumes.
#
# Encryption: LUKS2 container ("cryptroot") holding btrfs. Unlock is by
# passphrase, with optional TPM2 auto-unlock enrolled AFTER install (see the
# install notes at the bottom). btrfs gives copy-on-write snapshots via the
# @snapshots subvolume for easy rollbacks.
#
# This layout is applied at install with the `disko` command; it also supplies
# the fileSystems.* and boot.initrd.luks.* config at runtime.
{ config, lib, ... }:

{
  # systemd in the initrd is REQUIRED for TPM2-based LUKS unlocking.
  boot.initrd.systemd.enable = true;

  disko.devices = {
    disk.main = {
      type = "disk";

      # !!! SET THIS PER MACHINE !!!
      #  - QEMU/KVM virtio VM:  /dev/vda
      #  - Your real laptop:    /dev/nvme0n1   (prefer a stable /dev/disk/by-id/… path)
      # Check with `lsblk` in the installer. disko ERASES this whole disk.
      device = "/dev/vda";

      content = {
        type = "gpt";
        partitions = {
          # EFI System Partition.
          ESP = {
            priority = 1;
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          # Everything else: a LUKS2 container holding btrfs.
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";       # unlocked device: /dev/mapper/cryptroot
              settings = {
                allowDiscards = true;   # SSD TRIM through LUKS (minor info leak; fine for a laptop)
                # TPM2 auto-unlock. Harmless until you actually enroll the TPM
                # (see install notes). Remove this line to force passphrase-only.
                crypttabExtraOpts = [ "tpm2-device=auto" ];
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@"          = { mountpoint = "/";          mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@home"      = { mountpoint = "/home";      mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@nix"       = { mountpoint = "/nix";       mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@snapshots" = { mountpoint = "/.snapshots"; mountOptions = [ "compress=zstd" "noatime" ]; };
                };
              };
            };
          };
        };
      };
    };
  };
}

# ============================================================================
# INSTALL FLOW (from the NixOS installer, with this repo checked out):
#
#   1. Edit `device` above to match the target disk (lsblk to confirm).
#
#   2. Partition + encrypt + format + mount (prompts for the LUKS passphrase):
#        sudo nix --experimental-features "nix-command flakes" run \
#          github:nix-community/disko/latest -- \
#          --mode destroy,format,mount --flake .#nixos-niri
#
#   3. Generate hardware config WITHOUT filesystems (disko owns those):
#        sudo nixos-generate-config --no-filesystems --root /mnt
#      Then copy the generated /mnt/etc/nixos/hardware-configuration.nix into
#      this repo (next to flake.nix).
#
#   4. Install:
#        sudo nixos-install --flake .#nixos-niri
#
#   5. Reboot. First boot asks for the LUKS passphrase.
#
#   6. (Real hardware only) Enroll the TPM for auto-unlock — use the LUKS
#      PARTITION (e.g. /dev/nvme0n1p2), not /dev/mapper/cryptroot:
#        sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/nvme0n1p2
#      Next boot unlocks automatically; the passphrase still works as fallback.
# ============================================================================
