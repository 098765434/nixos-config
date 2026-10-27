# Settings that Shell Settings owns: managed/settings.json, keyed by
# managed/registry.nix. A key that's missing leaves the option to the rest of
# the config, so the hand-written modules win until a setting is moved here.
# Also ships the helper Settings runs (through polkit) to activate a built
# system, and the polkit action that guards it.
{ lib, pkgs, ... }:

let
  registry = import ../managed/registry.nix;
  settings = lib.importJSON ../managed/settings.json;
  set = r: lib.setAttrByPath r.path (lib.mkIf (settings ? ${r.id}) settings.${r.id});

  # amane-nixos-activate <switch|boot|test> <nixos-system store path | profile link>
  # Only ever runs a built NixOS system's own switch-to-configuration; every
  # refusal exits 2. `test` activates without recording a generation, so a
  # reboot undoes it.
  helper = pkgs.writeShellApplication {
    name = "amane-nixos-activate";
    runtimeInputs = [ pkgs.nix pkgs.coreutils ];
    text = ''
      [[ $# -eq 2 ]] || { echo "usage: amane-nixos-activate <switch|boot|test> <path>" >&2; exit 2; }
      mode=$1
      [[ $mode =~ ^(switch|boot|test)$ ]] || { echo "refused: mode $mode" >&2; exit 2; }
      out=$(readlink -f -- "$2") || { echo "refused: $2 does not resolve" >&2; exit 2; }
      [[ $out =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[^/]+$ ]] || { echo "refused: $out is not a NixOS system" >&2; exit 2; }
      [[ -x $out/bin/switch-to-configuration ]] || { echo "refused: $out has no switch-to-configuration" >&2; exit 2; }
      [[ $mode == test ]] || nix-env -p /nix/var/nix/profiles/system --set "$out"
      exec "$out/bin/switch-to-configuration" "$mode"
    '';
  };

  policy = pkgs.writeTextDir "share/polkit-1/actions/org.amane.nixos-activate.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <action id="org.amane.nixos-activate">
        <description>Apply system settings</description>
        <message>Shell Settings wants to apply system settings</message>
        <defaults>
          <allow_any>auth_admin</allow_any>
          <allow_inactive>auth_admin</allow_inactive>
          <allow_active>auth_admin_keep</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${helper}/bin/amane-nixos-activate</annotate>
      </action>
    </policyconfig>
  '';
in
{
  config = lib.mkMerge ([
    { environment.systemPackages = [ helper policy ]; }
  ] ++ map set registry);
}
