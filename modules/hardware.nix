# Hardware & low-level services for the AMD Ryzen AI 7 / Radeon 860M laptop.
{ config, pkgs, ... }:

{
  # Firmware blobs + AMD CPU microcode updates.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # AMD GPU (Radeon 860M). Mesa/RADV provides OpenGL + Vulkan (vulkan-radeon).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit libs for Steam/Heroic/Wine
  };

  # Bluetooth (GUI applet is services.blueman in desktop.nix).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fingerprint reader. After install, enroll with: fprintd-enroll
  services.fprintd.enable = true;

  # Power management (don't also enable TLP), firmware updates, zram, TRIM.
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
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
  };
}
