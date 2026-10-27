# Options of our own that Shell Settings can point at (managed/registry.nix
# addresses settings by option path, so what isn't an option gets one here):
# the idle timeouts behind hypridle's listener list, "installed but not
# started at boot" for a service, packages added from Settings, and how
# often to check for updates (a user timer that relocks beside the repo,
# never building, and notifies through the shell).
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.amane;
  t = lib.types;
  # a package added from Settings, or null when nixpkgs no longer has it:
  # a removed package is usually an alias that throws ("… has been renamed")
  resolve = name:
    let r = builtins.tryEval (lib.attrByPath (lib.splitString "." name) null pkgs);
    in if r.success then r.value else null;
  missing = builtins.filter (name: resolve name == null) cfg.packages;
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

  # amane-update-check: relocks the flake into the shell's state dir (the
  # repo's flake.lock is untouched), writes check.json with what changed,
  # and notifies once per new set of changes; clicking the toast opens
  # Shell Settings → Software Update. A check that can't reach the network
  # only records why.
  amaneShell = inputs.amane-shell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  updateCheck = pkgs.writeShellApplication {
    name = "amane-update-check";
    runtimeInputs = [ pkgs.nix pkgs.jq pkgs.libnotify pkgs.coreutils pkgs.git amaneShell ];
    text = ''
      repo="$HOME/nixos-config"
      dir="''${XDG_STATE_HOME:-$HOME/.local/state}/amane-shell/nixos"
      mkdir -p "$dir"
      now=$(date +%s)

      if ! nix flake update --flake "$repo" --output-lock-file "$dir/check.lock" --no-warn-dirty 2>"$dir/check.err"; then
        jq -n --argjson now "$now" --rawfile err "$dir/check.err" \
          '{checked: $now, changes: [], error: (($err | split("\n") | map(select(length > 0)) | last) // "nix flake update failed")}' \
          > "$dir/check.json.tmp"
        mv "$dir/check.json.tmp" "$dir/check.json"
        exit 0
      fi

      jq -n --argjson now "$now" --slurpfile old "$repo/flake.lock" --slurpfile new "$dir/check.lock" '
        def revs(l): l[0] as $l
          | [$l.nodes.root.inputs | to_entries[] | {key: .key, value: ($l.nodes[.value].locked.rev // "")}]
          | from_entries;
        revs($old) as $o | revs($new) as $n
        | {checked: $now,
           changes: [$o | to_entries[] | select($n[.key] != null and $n[.key] != .value)
                     | {name: .key, from: .value, to: $n[.key]}]}
      ' > "$dir/check.json.tmp"
      mv "$dir/check.json.tmp" "$dir/check.json"

      names=$(jq -r '[.changes[].name] | join(", ")' "$dir/check.json")
      [ -n "$names" ] || exit 0
      if [ "$(jq -c .changes "$dir/check.json")" = "$(jq -c .changes "$dir/notified.json" 2>/dev/null || true)" ]; then
        exit 0
      fi
      cp "$dir/check.json" "$dir/notified.json"
      if notify-send -a "Software Update" -i system-software-update --action=default=Open \
           "Updates available" "$names" | grep -q '^default$'; then
        amane-settings --page update
      fi
    '';
  };
  checkEvery = {
    daily = "daily";
    weekly = "weekly";
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
    missingPackages = lib.mkOption {
      type = t.listOf t.str;
      readOnly = true;
      default = missing;
      description = "The `packages` this nixpkgs doesn't have (any more): left out, with a warning.";
    };
    updates.check = lib.mkOption {
      type = t.enum [ "daily" "weekly" "never" ];
      default = "daily";
      description = "How often a user timer checks the flake's inputs for updates (no build) and notifies.";
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

    # one nixpkgs dropped is left out with a warning rather than failing the
    # build; Shell Settings → Apps shows it as gone (amaneSettings.missingPackages)
    environment.systemPackages =
      builtins.filter (p: p != null) (map resolve cfg.packages);
    warnings = map
      (name: "amane.packages: ${name} isn't in this nixpkgs any more (renamed or removed); remove it in Shell Settings → Apps.")
      missing;

    # the update check, as a user timer (it needs the session bus for the
    # toast and the user's nix settings); `systemctl --user start
    # amane-update-check` runs one now
    home-manager.users.ocbk.systemd.user = lib.mkIf (cfg.updates.check != "never") {
      services.amane-update-check = {
        Unit.Description = "Check the NixOS configuration's inputs for updates";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe updateCheck;
        };
      };
      timers.amane-update-check = {
        Unit.Description = "Check for NixOS updates ${cfg.updates.check}";
        Timer = {
          OnCalendar = checkEvery.${cfg.updates.check};
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

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
