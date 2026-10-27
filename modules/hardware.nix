# Hardware & low-level services for the AMD Ryzen AI 7 / Radeon 860M laptop.
{ config, lib, pkgs, ... }:

{
  # Latest kernel — this is very new AMD silicon (Ryzen AI 7 450 / Krackan Point,
  # Radeon 860M / RDNA 3.5), which benefits from the newest GPU/power/sensor support.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Firmware blobs + AMD CPU microcode updates.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # AMD GPU (Radeon 860M). Mesa/RADV provides OpenGL + Vulkan (vulkan-radeon).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit libs for Steam/Heroic/Wine
  };

  # Bluetooth (controls are the shell's quick-settings tile and page; the
  # shell is BlueZ's pairing agent, so devices that need a PIN pair there too).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fingerprint reader. After install, enroll with: fprintd-enroll
  services.fprintd.enable = true;

  # Power management (don't also enable TLP), firmware updates, zram, TRIM.
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
  # No background metadata refresh: that timer is what wakes fwupd and leaves
  # it resident. Run `fwupdmgr refresh && fwupdmgr update` by hand instead.
  systemd.timers.fwupd-refresh.wantedBy = lib.mkForce [ ];
  zramSwap.enable = true;
  services.fstrim.enable = true;

  # External-monitor brightness over DDC/CI (ddcutil). User is in "i2c" group.
  hardware.i2c.enable = true;

  # ---------------------------------------------------------------------------
  # Audio (PipeWire)
  # ---------------------------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # wireplumber (provides wpctl for the niri volume binds) is on by default.

    # PipeWire's X11-bell module opens DISPLAY at login to play the terminal
    # bell through libcanberra. Under niri that connection is what starts
    # xwayland-satellite's Xwayland (about 85 MB of RSS between them) three
    # seconds after login, with no X app running. Nothing here rings an X11
    # bell, so the module stays off; X apps still get Xwayland on demand.
    extraConfig.pipewire."99-no-x11-bell" = {
      "context.properties" = {
        "module.x11.bell" = false;
      };
    };
  };
}
