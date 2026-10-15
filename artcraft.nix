# ArtCraft creative apps (https://github.com/storytold).
#
# Not in nixpkgs, so we wrap their upstream Linux AppImages with appimageTools.
# Versions + hashes live in ./artcraft-sources.json (pinned for reproducibility).
# To pull the NEWEST releases, run ./update-artcraft.sh then `nixos-rebuild`.
# wrapType2 extracts each AppImage's .desktop file + icon, so the apps show up
# in your launcher (wofi). Needs programs.appimage (enabled in configuration.nix).
{ pkgs, lib, ... }:

let
  sources = builtins.fromJSON (builtins.readFile ./artcraft-sources.json);

  # Build one ArtCraft app from its pinned x86_64 AppImage release asset.
  mkArtcraft = pname: { version, hash }:
    pkgs.appimageTools.wrapType2 {
      inherit pname version;
      src = pkgs.fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
        inherit hash;
      };
      # If an app complains about a missing library at runtime, add it here, e.g.:
      # extraPkgs = p: [ p.libGL p.vulkan-loader ];
    };
in
{
  environment.systemPackages = lib.mapAttrsToList mkArtcraft sources;
}
