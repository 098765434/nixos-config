# niri desktop: compositor, greeter, portals, polkit, app integration, fonts.
{ config, pkgs, lib, ... }:

{
  # niri compositor — installs it, registers the Wayland session, wires polkit
  # + portals. Module comes from niri-flake (see flake.nix). The package is
  # pulled from nixpkgs rather than niri-flake's `niri-stable`: niri-flake has
  # been slow to bump that pin (still v25.08 as of writing) while nixpkgs
  # 26.05 already ships the latest upstream release. Trade-off: we lose
  # niri.cachix.org for this build, but cache.nixos.org has it prebuilt.
  # Your niri config.kdl is managed per-user in ./home via a mkOutOfStoreSymlink.
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # greetd + tuigreet: tiny TTY greeter that lists sessions (pick "niri").
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  # XDG portals (screen share, file pickers). niri module adds the GTK portal.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # GTK/GNOME apps need dconf to store settings.
  programs.dconf.enable = true;

  # KDE Connect (opens its own firewall ports).
  programs.kdeconnect.enable = true;

  # Bluetooth tray applet (works better under niri than gnome-control-center).
  services.blueman.enable = true;

  # Flatpak — chiefly your browser (Zen). After first boot:
  #   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #   flatpak install flathub app.zen_browser.zen
  services.flatpak.enable = true;

  # AppImage support (FHS sandbox) — runs the ArtCraft AppImages.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Polkit authentication agent — niri doesn't start one itself; without it,
  # privileged GUI actions fail silently. Check: systemctl --user status hyprpolkitagent
  security.polkit.enable = true;
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = lib.getExe pkgs.hyprpolkitagent;
      Restart = "on-failure";
    };
  };

  # zoxide (smarter cd) with bash integration.
  programs.zoxide.enable = true;

  # ---------------------------------------------------------------------------
  # Fonts
  # ---------------------------------------------------------------------------
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji     # was noto-fonts-emoji (renamed in 26.05)
    nerd-fonts.jetbrains-mono
    nerd-fonts.mononoki
    atkinson-hyperlegible-mono # used by the waybar style.css
    atkinson-hyperlegible-next
    # Google's github.com/google/material-design-icons — classic Material Icons
    # plus the newer variable-font Material Symbols.
    material-icons
    material-symbols
  ];
}
