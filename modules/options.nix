# Options of our own that Shell Settings can point at (managed/registry.nix
# addresses settings by option path, so what isn't an option gets one here):
# the idle timeouts behind hypridle's listener list, "installed but not
# started at boot" for a service, and packages added from Settings.
{ config, lib, pkgs, ... }:

let
  cfg = config.amane;
  t = lib.types;
  seconds = default: what: lib.mkOption {
    type = t.ints.unsigned;
    inherit default;
    description = "${what}, in seconds; 0 = never.";
  };
  onDemand = what: lib.mkOption {
    type = t.bool;
    default = false;
    description = "Install ${what} but don't start it at boot: start it by hand when needed.";
  };
in
{
  options.amane = {
    idle.dimAfter = seconds 180 "Dim the screen after";
    idle.lockAfter = seconds 240 "Lock the screen after";
    idle.screenOffAfter = seconds 300 "Turn the screen off after";
    services.sshd.onDemand = onDemand "the SSH server";
    services."avahi-daemon".onDemand = onDemand "Avahi";
    packages = lib.mkOption {
      type = t.listOf t.str;
      default = [ ];
      description = "nixpkgs attribute paths (dotted) added from Shell Settings → Apps.";
    };
  };

  config = {
    # mkIf around mkForce: no definition at all while it's off, so the unit
    # keeps its own wantedBy. Gated on the service, so a unit that doesn't
    # exist isn't given one.
    systemd.services.sshd.wantedBy =
      lib.mkIf (cfg.services.sshd.onDemand && config.services.openssh.enable) (lib.mkForce [ ]);
    systemd.services.avahi-daemon.wantedBy =
      lib.mkIf (cfg.services."avahi-daemon".onDemand && config.services.avahi.enable) (lib.mkForce [ ]);

    environment.systemPackages =
      map (name: lib.getAttrFromPath (lib.splitString "." name) pkgs) cfg.packages;

    # hypridle's listeners, in timeout order; a timeout of 0 leaves one out.
    home-manager.users.ocbk.services.hypridle.settings.listener =
      lib.optional (cfg.idle.dimAfter > 0) {
        timeout = cfg.idle.dimAfter;
        on-timeout = "brightnessctl -s set 10%";
        on-resume = "brightnessctl -r";
      }
      ++ lib.optional (cfg.idle.lockAfter > 0) {
        timeout = cfg.idle.lockAfter;
        on-timeout = "loginctl lock-session";
      }
      ++ lib.optional (cfg.idle.screenOffAfter > 0) {
        timeout = cfg.idle.screenOffAfter;
        on-timeout = "niri msg action power-off-monitors";
        on-resume = "niri msg action power-on-monitors";
      };
  };
}
