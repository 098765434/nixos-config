# Gaming: Steam + gamescope + gamemode. (Heroic is a package in apps.nix;
# MangoHud is a package in apps.nix.)
{ pkgs, ... }:

{
  # Steam MUST go through this module (not just the package): it provides the
  # FHS runtime, 32-bit graphics, controller udev rules, and firewall ports.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;       # Steam Remote Play
    dedicatedServer.openFirewall = false; # not hosting servers
    gamescopeSession.enable = true;       # optional gamescope session at the greeter

    # Windows games via Proton: GE-Proton as a global fallback compat tool.
    # Pick it per-game in Steam > Properties > Compatibility, or set it as the
    # default. proton-ge-bin is unfree-free (open source) — no allowUnfree needed.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # gamescope: micro-compositor for games. gamescopeSession above only ships the
  # binary; THIS enables the setcap wrapper (CAP_SYS_NICE) so gamescope can take
  # realtime priority / SCHED_RR for smoother frame pacing. Also the path to FSR
  # upscaling, which matters on this iGPU (render low, upscale to panel res):
  #   gamescope -W 2880 -H 1800 -w 1280 -h 720 -U -f -- gamemoderun %command%
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # On-demand performance tuning games can request: gamemoderun %command%
  programs.gamemode = {
    enable = true;
    settings.general = {
      # Keep the screen awake while a game runs. gamemode inhibits via the
      # org.freedesktop.ScreenSaver D-Bus interface, which hypridle honours
      # (ignore_dbus_inhibit = false in home/home.nix) — so this stops the
      # 4-min idle lock / 5-min DPMS-off from firing mid-game, since controller
      # input does NOT reset hypridle's idle timer. (Default is already 1;
      # pinned explicitly so the hypridle interaction is documented, not luck.)
      inhibit_screensaver = 1;
    };
  };
}
