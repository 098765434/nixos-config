# configuration.nix — core system module.
#
# Entry point is flake.nix. This file holds the machine basics and pulls in the
# topic modules under ./modules, the ArtCraft apps, and the hardware scan.
# Per-user dotfiles (niri, waybar) live in ./home via home-manager.
#
# Rebuild with:  sudo nixos-rebuild switch --flake .#nixos-niri

{ config, pkgs, lib, ... }:

{
  imports = [
    # Generated INSIDE the machine by `nixos-generate-config` (disks, kernel
    # modules, filesystems). Must exist for the flake to build — it's created
    # during install and is machine-specific.
    ./hardware-configuration.nix

    ./modules/disk.nix
    ./modules/hardware.nix
    ./modules/desktop.nix
    ./modules/gaming.nix
    ./modules/services.nix
    ./modules/apps.nix

    # ArtCraft creative apps (vectorcraft, figcraft, photocraft, designcraft).
    ./artcraft.nix
  ];

  # ---------------------------------------------------------------------------
  # Bootloader (UEFI, systemd-boot)
  # ---------------------------------------------------------------------------
  boot.loader.systemd-boot = {
    enable = true;
    # Cap stored boot entries. Your /boot is only ~1 GB, so unbounded
    # generations would eventually fill it and break rebuilds.
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostName = "nixos-niri";
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Locale / time / keyboard (Norwegian — adjust to taste)
  # ---------------------------------------------------------------------------
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "no";
  # niri's xkb section is empty, so it reads the layout from locale1, set here.
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  # ---------------------------------------------------------------------------
  # User account
  # ---------------------------------------------------------------------------
  users.users.ocbk = {
    isNormalUser = true;
    description = "ocbk";
    extraGroups = [
      "wheel"           # sudo
      "networkmanager"
      "video"
      "audio"
      "i2c"             # ddcutil (external-monitor brightness) without root
    ];
    # TODO (daily driver): replace this plaintext password with a hash so it's
    # not stored in the repo. Generate one with:  mkpasswd -m sha-512
    # then swap to:  hashedPassword = "$6$...";
    initialPassword = "nixos";
  };
  security.sudo.wheelNeedsPassword = true;

  environment.variables.EDITOR = "nvim";

  # Unfree packages (vscode, obsidian, steam, …).
  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------------------
  # Nix settings
  # ---------------------------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Hardlink identical files in the store to reclaim disk (your disk is tight).
    auto-optimise-store = true;
  };
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ---------------------------------------------------------------------------
  # State version — pins default settings to the release first installed.
  # Do NOT bump casually; match it to the ISO/channel you install from.
  # ---------------------------------------------------------------------------
  system.stateVersion = "26.05";
}
