# Energy: what the laptop does to use less power, each behind an option that
# Emaki Settings → Power & Lock shows (managed/registry.nix, page "energy",
# and the idle chain on page "power"). Imported from modules/options.nix.
#
# Measured on this ThinkPad T14 Gen 7 (Krackan, OLED) in the 2026-11-12 audit:
# PCI devices never runtime-suspended, ASPM at the BIOS default, Bluetooth
# powered with nothing connected, no idle suspend (about 8 W, open and idle,
# until the battery ran out), Syncthing announcing and relaying, the store
# hardlinked on every build. Power profiles stay power-profiles-daemon's,
# switched by the shell's battery mode; don't add TLP or auto-cpufreq.
{ config, lib, pkgs, ... }:

let
  cfg = config.emaki;
  t = lib.types;
in
{
  options.emaki = {
    idle.suspendOnBatteryAfter = lib.mkOption {
      type = t.ints.unsigned;
      default = 900;
      description = "Suspend after this long idle, on battery only, in seconds; 0 = never.";
    };
    power.devices = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Power saving for devices: PCI runtime power management (display
        controllers left to their driver), PCIe ASPM `powersupersave`, no NMI
        watchdog, dirty pages written back every 15 s instead of 5 s.
        Takes effect after a restart.
      '';
    };
    wifi.powerSave = lib.mkOption {
      type = t.bool;
      default = true;
      description = "Wi-Fi power saving (NetworkManager's powersave).";
    };
    bluetooth.onAtStart = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Bluetooth's radio on at startup; off, it's switched on from Quick Settings when needed.";
    };
    nix.optimiseWeekly = lib.mkOption {
      type = t.bool;
      default = true;
      description = "Deduplicate the Nix store once a week instead of during every build.";
    };
    journal.maxUse = lib.mkOption {
      type = t.enum [ "100M" "200M" "500M" "1G" ];
      default = "200M";
      description = "The most disk the system journal keeps.";
    };
    syncthing.direct = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Syncthing reaches pi5 straight over Tailscale: no local or global
        discovery, relays or NAT traversal running in the background.
      '';
    };
    autostart.bitwarden = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Start the Bitwarden desktop app at login (the browser extension and rbw work without it).";
    };
  };

  config = lib.mkMerge [
    {
      networking.networkmanager.wifi.powersave = cfg.wifi.powerSave;
      hardware.bluetooth.powerOnBoot = cfg.bluetooth.onAtStart;

      # builds and switches yield to the desktop
      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";

      # measuring, not tuning: no powertop --auto-tune service
      environment.systemPackages = [ pkgs.powertop pkgs.amd-debug-tools pkgs.iw ];

      # kernel messages (amd_pmc, AER, Panel Replay) without sudo
      users.users.ocbk.extraGroups = [ "systemd-journal" ];

      services.journald.extraConfig = ''
        SystemMaxUse=${cfg.journal.maxUse}
        MaxRetentionSec=2week
      '';
    }

    (lib.mkIf cfg.power.devices {
      boot.kernelParams = [ "pcie_aspm.policy=powersupersave" "nmi_watchdog=0" ];
      boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 1500;
      # runtime PM for every PCI function but the GPU (amdgpu manages its
      # own; an APU doesn't runtime-suspend). The unused Realtek ethernet
      # then sleeps with no link.
      services.udev.extraRules = ''
        ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{class}!="0x03*", TEST=="power/control", ATTR{power/control}="auto"
      '';
    })

    (lib.mkIf cfg.nix.optimiseWeekly {
      # configuration.nix sets it on; weekly instead
      nix.settings.auto-optimise-store = lib.mkForce false;
      nix.optimise.automatic = true;
      nix.optimise.dates = [ "weekly" ];
    })

    (lib.mkIf (cfg.syncthing.direct && config.services.syncthing.enable) {
      services.syncthing.settings = {
        options = {
          localAnnounceEnabled = false;
          globalAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
          urAccepted = -1;
        };
        devices.pi5.addresses = [ "tcp://pi5.tail8c36e9.ts.net:22000" ];
      };
    })

    (lib.mkIf (!cfg.autostart.bitwarden) {
      # the app writes its own autostart entry; this one hides it
      home-manager.users.ocbk.xdg.configFile."autostart/bitwarden.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Bitwarden
          Hidden=true
        '';
      };
    })

    {
      # suspend after the screen has been off a while, on battery only (AC*
      # or ADP*: the adapter's sysfs name). Lists merge with the dim, lock
      # and screen-off listeners in options.nix; hypridle honours inhibitors.
      home-manager.users.ocbk.services.hypridle.settings.listener =
        lib.optional (cfg.idle.suspendOnBatteryAfter > 0) {
          timeout = cfg.idle.suspendOnBatteryAfter;
          on-timeout = "grep -qs 1 /sys/class/power_supply/A*/online || systemctl suspend";
        };
    }
  ];
}
