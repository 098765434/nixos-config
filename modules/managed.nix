# Settings that Emaki Settings owns: managed/settings.json, keyed by
# managed/registry.nix. A key that's missing leaves the option to the rest of
# the config, so the hand-written modules win until a setting is moved here.
# The helper Settings runs (through polkit) to activate a built system, and
# the polkit action that guards it, come from emaki's NixOS module
# (nix/nixos-module.nix there): it asks for the password every time and shows
# the store path it activates.
{ lib, ... }:

let
  registry = import ../managed/registry.nix;
  settings = lib.importJSON ../managed/settings.json;
  set = r: lib.setAttrByPath r.path (lib.mkIf (settings ? ${r.id}) settings.${r.id});

in
{
  config = lib.mkMerge ([
    { programs.emaki.nixosActivate.enable = true; }
  ] ++ map set registry);
}
