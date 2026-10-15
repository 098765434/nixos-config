# Gaming: Steam + gamemode. (Heroic is a package in apps.nix.)
{ pkgs, ... }:

{
  # Steam MUST go through this module (not just the package): it provides the
  # FHS runtime, 32-bit graphics, controller udev rules, and firewall ports.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;       # Steam Remote Play
    dedicatedServer.openFirewall = false; # not hosting servers
    gamescopeSession.enable = true;       # optional gamescope session at the greeter
    # For Windows games via Proton, add GE-Proton later:
    # extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # On-demand performance tuning games can request: gamemoderun %command%
  programs.gamemode.enable = true;
}
