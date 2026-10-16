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
    ./modules/security.nix
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
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    # Privacy: randomize the Wi-Fi MAC so networks can't track your hardware
    # address across locations. Use "stable" instead if a captive portal or a
    # MAC-allowlisted network gives you trouble.
    wifi.macAddress = "random";
    # Hand DNS to systemd-resolved (encrypted DNS configured in services.nix).
    dns = "systemd-resolved";

    # Declarative Wi-Fi profile. The SSID lives here; the PSK does NOT — it is
    # read at activation from a local env file that is never in the Nix store or
    # git. Create it on the machine, root-owned and chmod 600:
    #     /etc/nm-secrets.env  ->  HOME_WIFI_PSK=your-actual-password
    ensureProfiles = {
      environmentFiles = [ "/etc/nm-secrets.env" ];
      profiles.home-wifi = {
        connection = { id = "home-wifi"; type = "wifi"; };
        wifi.ssid = "TP-Link_3CEE";
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$HOME_WIFI_PSK";   # substituted from environmentFiles
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };

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

  # Android Debug Bridge: on 26.05 (systemd 258) `programs.adb` is gone — device
  # uaccess is handled automatically for the logged-in user, so adb just needs
  # the tools, which live in android-tools (modules/apps.nix). No group needed.

  environment.variables.EDITOR = "nvim";

  # ---------------------------------------------------------------------------
  # nix-ld — run generic dynamically-linked executables
  # ---------------------------------------------------------------------------
  # Binaries built for ordinary distros ask for /lib64/ld-linux-x86-64.so.2,
  # which on NixOS is only a stub that errors out. nix-ld puts a real loader
  # there. Needed by things Nix doesn't package: VS Code extension binaries
  # (e.g. the Claude Code extension's bundled CLI), language servers, installers.
  # Pure-glibc binaries work as-is; add libraries to programs.nix-ld.libraries
  # if something still reports a missing .so.
  programs.nix-ld.enable = true;

  # Unfree packages (vscode, obsidian, steam, …).
  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------------------
  # Nix settings
  # ---------------------------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Hardlink identical files in the store to reclaim disk (dedupes on every build).
    auto-optimise-store = true;
  };
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
