# Security: screen-lock PAM + Secure Boot (lanzaboote, staged).
{ config, lib, pkgs, ... }:

{
  # swaylock needs its own PAM entry on NixOS, or it can never authenticate and
  # you'd be locked out of your own session. (The screen auto-lock lives in
  # home-manager's hypridle config.)
  security.pam.services.swaylock = {};

  # sbctl manages the Secure Boot signing keys.
  environment.systemPackages = [ pkgs.sbctl ];

  # ===========================================================================
  # SECURE BOOT (lanzaboote) — STAGED. Do NOT enable on the first install:
  # signing needs keys that don't exist yet. Enable only after enrolling them.
  #
  #   1. Install + boot normally first (systemd-boot, unsigned).
  #   2. Create keys:            sudo sbctl create-keys
  #   3. Uncomment the block below, then:
  #                              sudo nixos-rebuild switch --flake .#nixos-niri
  #   4. Reboot into firmware, put Secure Boot into "Setup Mode" (clear keys).
  #   5. Enroll (include Microsoft keys for firmware / GPU option-ROM compat):
  #                              sudo sbctl enroll-keys --microsoft
  #   6. Enable Secure Boot in firmware, reboot.
  #   7. Verify:                 sbctl status     # should show signed
  #                              bootctl status   # "Secure Boot: enabled"
  # ===========================================================================
  # boot.loader.systemd-boot.enable = lib.mkForce false;   # lanzaboote replaces it
  # boot.lanzaboote = {
  #   enable = true;
  #   pkiBundle = "/var/lib/sbctl";   # must match where sbctl stores keys
  #   configurationLimit = 10;
  # };
}
