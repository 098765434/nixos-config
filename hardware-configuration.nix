# Hardware scan — ThinkPad T14 Gen 7 (AMD Ryzen AI 7 PRO 450 / Radeon 860M,
# WD PC SN7100S 256 GB NVMe).
#
# Normally produced by `nixos-generate-config --no-filesystems`. Pre-committed
# here (hand-written from the real hardware: `lsblk`/`lspci`/`lsmod` on the
# machine) so the flake — and the disko step that reads it — can EVALUATE before
# the OS exists. Without this file the `imports` in configuration.nix fails, and
# `disko ... --flake .#nixos-niri` can't even run.
#
# Filesystems/swap are intentionally ABSENT: modules/disk.nix (disko) owns
# fileSystems.* and boot.initrd.luks.* — that's why the install uses
# `--no-filesystems`.
#
# After install you can regenerate and diff to confirm nothing hardware-specific
# is missing:
#   sudo nixos-generate-config --no-filesystems --root /mnt
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Modules the initrd needs to find + mount the encrypted NVMe root. Verified
  # loaded on the running machine (nvme + USB/HID for the LUKS passphrase prompt;
  # thunderbolt for the USB4 controller on this ThinkPad).
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];

  # AMD virtualization (KVM).
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
