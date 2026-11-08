# niri desktop: compositor, greeter, portals, polkit, app integration, fonts.
{ config, pkgs, lib, inputs, ... }:

{
  # niri compositor — installs it, registers the Wayland session, wires polkit
  # + portals. Module comes from niri-flake (see flake.nix). The package is our
  # local fork (inputs.niri-fork), which adds live gesture-progress IPC events
  # on top of the v26.04 base that matches nixpkgs 26.05's niri. Built from the
  # fork's own flake (buildRustPackage), so this compiles niri locally — no
  # cache.nixos.org hit — and only COMMITTED changes on the fork are built.
  # Revert to upstream by setting `package = pkgs.niri;`.
  # Your niri config.kdl is managed per-user in ./home via a mkOutOfStoreSymlink.
  programs.niri = {
    enable = true;
    # One codegen unit: a few percent less CPU per frame and a smaller binary,
    # for a slower build. Set here so the fork's Cargo.toml stays upstream's.
    package = inputs.niri-fork.packages.${pkgs.system}.niri.overrideAttrs (old: {
      env = (old.env or { }) // { CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1"; };
    });
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

  # KDE Connect (opens its own firewall ports): `kdeconnect` in
  # managed/settings.json (Shell Settings → Services).

  # The phone's screen and camera beside it (amane-mirror, scrcpy's server
  # over adb): Wireless debugging announces itself over mDNS, which the
  # shell listens for, and the phone's camera is a loopback webcam named
  # "Phone Camera" (video call apps list it; exclusive_caps lets browsers).
  networking.firewall.allowedUDPPorts = [ 5353 ];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 card_label="Phone Camera"
  '';

  # Flatpak — chiefly your browser (Zen). After first boot:
  #   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #   flatpak install flathub app.zen_browser.zen
  # Switched on as `flatpak` in managed/settings.json (Shell Settings).

  # AppImage support (FHS sandbox) — runs the ArtCraft AppImages.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Polkit: the shell is the session's authentication agent (amane-shell
  # registers org.freedesktop.PolicyKit1.AuthenticationAgent and asks for
  # the password in its own alert), so the niri flake's polkit-kde agent
  # stays off. Check: busctl --system call … CheckAuthorization, or
  # `systemctl --user start sshd`-style prompts from Shell Settings.
  security.polkit.enable = true;
  systemd.user.services.niri-flake-polkit.enable = false;

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
