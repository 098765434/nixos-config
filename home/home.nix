# home-manager configuration for user "ocbk".
#
# Manages your per-user dotfiles declaratively. Edit the sources in this repo
# and run `nixos-rebuild switch`; the files become read-only symlinks in
# ~/.config. `inputs` is passed through from the flake (extraSpecialArgs).
{ config, pkgs, inputs, lib, ... }:

{
  # NOTE: do NOT import inputs.niri.homeModules.niri here. niri-flake's NixOS
  # module (niri.nixosModules.niri in flake.nix) already injects the niri
  # home-manager module into every home-manager user, so importing it again
  # declares programs.niri.* twice and fails eval:
  #   "option home-manager.users.ocbk.programs.niri.finalConfig is already declared".
  # programs.niri.config below still resolves against that auto-injected module.

  home.stateVersion = "26.05";

  # niri + waybar configs are symlinked straight at the repo working tree so
  # edits take effect without a rebuild (niri auto-reloads config.kdl on save;
  # reload waybar with `pkill -SIGUSR2 waybar`). Trade-off vs. the previous
  # `programs.niri.config = readFile ...` setup: niri-flake no longer parses
  # the KDL at build time, so bad syntax surfaces at reload instead of rebuild.
  # The symlink target is absolute — the repo must live at ~/nixos-config.
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/niri/config.kdl";
  xdg.configFile."waybar/config".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/waybar/config";
  xdg.configFile."waybar/style.css".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/waybar/style.css";

  # KDE Connect's daemon starts at login from its own system autostart entry
  # (present while `kdeconnect` is on in Emaki Settings → Services, which also
  # opens its ports). emaki draws all of its UI: the Quick Settings Phone
  # page and emaki-messages.
  #
  # nm-applet has a system autostart entry besides the (now disabled) niri
  # spawn; this Hidden= entry masks it, since the shell's network tiles
  # replace it.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';

  # The shell's own app icons, each named after an app's Icon= key. ~/.local/share
  # is searched before the system dirs, so these replace the apps' own icons.
  # The ArtCraft apps wear their Adobe equivalents (photocraft = Photoshop,
  # vectorcraft = Illustrator, designcraft = InDesign, figcraft = Figma).
  xdg.dataFile = lib.mapAttrs' (file: _:
    lib.nameValuePair "icons/hicolor/512x512/apps/${file}"
      { source = ./icons/${file}; })
    (builtins.readDir ./icons);

  # --- XDG user directories ---
  # niri has no desktop environment to run xdg-user-dirs, so nothing would create
  # the standard folders on first login — declare them here instead. Enabling the
  # module writes the FULL set with defaults (and would create Desktop/Music/etc),
  # so the unwanted ones are explicitly set to null to drop them.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;            # mkdir the standard dirs below
    documents = "${config.home.homeDirectory}/Documents";
    download  = "${config.home.homeDirectory}/Downloads";
    pictures  = "${config.home.homeDirectory}/Pictures";
    templates = "${config.home.homeDirectory}/Templates";  # nautilus "New Document"
    # Dropped — not used on this setup:
    desktop     = null;
    music       = null;
    videos      = null;
    publicShare = null;
    # Non-standard extra: register ~/Projects as an XDG dir. createDirectories
    # only makes the standard dirs, so the folder itself is ensured below.
    extraConfig.XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
  };

  # Ensure ~/Projects exists as a real, writable directory (not a store symlink),
  # since xdg.userDirs.createDirectories doesn't cover extraConfig entries.
  home.activation.ensureProjectsDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "$HOME/Projects"
    '';

  # --- Terminal: foot ---
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        dpi-aware = "yes";
      };
      colors = {
        background = "232629";
        foreground = "eff0f1";
      };
    };
  };

  # --- Launcher: wofi ---
  programs.wofi = {
    enable = true;
    settings = {
      show = "drun";
      width = 600;
      lines = 8;
      prompt = "Search";
      allow_images = true;
    };
    style = ''
      window { background-color: #232629; color: #eff0f1; border-radius: 8px;
               font-family: "JetBrainsMono Nerd Font"; }
      #input { margin: 6px; border-radius: 6px; background-color: #31363b;
               color: #eff0f1; border: none; }
      #entry:selected { background-color: #31363b; border-radius: 6px; }
    '';
  };

  # --- Notifications: emaki ---
  # The bar below is the notification daemon (toasts, center, Do Not Disturb),
  # so mako is gone: only one program can own org.freedesktop.Notifications.

  # --- Idle: hypridle (ported from ~/.config/hypridle on Arch) ---
  # Replaces the niri `spawn-at-startup "hypridle"`.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        ignore_dbus_inhibit = false;
        # Security: lock the screen on idle and before sleep. loginctl emits the
        # lock signal; hypridle's lock_cmd then runs swaylock (single instance).
        lock_cmd = "pidof swaylock || swaylock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "niri msg action power-on-monitors";
      };
      # The listeners (dim, lock, screen off) come from emaki.idle.* in
      # managed/settings.json (Emaki Settings → Power & Lock); see
      # modules/options.nix. Don't add any here: the list would be merged.
    };
  };

  # Screen locker — used by hypridle's lock_cmd and the niri Super+Alt+L bind.
  # Authentication works via the system PAM entry (modules/security.nix).
  programs.swaylock = {
    enable = true;
    settings = {
      color = "232629";
      indicator-radius = 100;
      indicator-thickness = 7;
      show-failed-attempts = true;
    };
  };

  # --- Bar: emaki (custom niri status bar) ---
  # Installed from the flake input and run as a user service bound to the niri
  # graphical session, so it starts on login and restarts on crash (logs via
  # `journalctl --user -u emaki`) — mirrors the hypridle pattern and
  # replaces a niri `spawn-at-startup`. Default theme is dark; to switch, add
  # Environment = [ "AMANE_THEME=light" ] to Service below.
  # The bar's blur/rounding also needs its niri layer-rules: run
  # `~/Projects/desktop/shell/gen-layer-rules.sh ~/nixos-config/niri/config.kdl`.
  home.packages = [ inputs.emaki.packages.${pkgs.system}.default ];
  systemd.user.services.emaki = {
    Unit = {
      Description = "emaki bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.emaki.packages.${pkgs.system}.default}/bin/emaki";
      Restart = "on-failure";
      # it passes passwords from rbw into fields: no core dump of it, or of the rbw agent
      # it starts (which inherits this), may land on disk
      LimitCORE = 0;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # --- Drop: emaki-drop (a drop shelf in the status bar) ---
  # Its own unit, so it isn't in emaki's cgroup and a restart of the
  # shell doesn't take it down; it puts its item back in the bar once the
  # shell's org.emaki.StatusBar1 is there again. "Quit Drop" in its menu exits
  # cleanly, which leaves it stopped until the next login or Mod+Shift+D.
  # curl, secret-tool and wl-copy come with the package's wrapper.
  systemd.user.services.emaki-drop = {
    Unit = {
      Description = "emaki-drop (Drop: a grid of folders, apps and uploads)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.emaki.packages.${pkgs.system}.default}/bin/emaki-drop";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # --- Assistant: emaki-assistant (the launcher's commands, typed or spoken) ---
  # Cactus (Needle 3 + Whistle) on the CPU, models from the store; the shell
  # talks to it over $XDG_RUNTIME_DIR/emaki-assistant.sock and works without
  # it. Kept to Unix sockets: it reads everything here and never needs the
  # network (Cactus has no network code; this makes sure). The microphone is
  # PulseAudio's socket, only while Mod+Shift+Space listens.
  systemd.user.services.emaki-assistant = {
    Unit = {
      Description = "emaki assistant (Cactus)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.emaki.packages.${pkgs.system}.default}/bin/emaki-assistant";
      Restart = "on-failure";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      NoNewPrivileges = true;
      LockPersonality = true;
      MemoryMax = "1G";
      Environment = [
        "CACTUS_TELEMETRY=0"
        "DO_NOT_TRACK=1"
      ];
    };
    # Started by its socket (below) at the shell's first request, and gone
    # again after 5 minutes with nothing asked (AMANE_ASSISTANT_IDLE), which
    # gives its models' 80-140 MB back.
  };
  systemd.user.sockets.emaki-assistant = {
    Unit.Description = "emaki assistant's socket";
    Socket = {
      ListenStream = "%t/emaki-assistant.sock";
      SocketMode = "0600";
    };
    Install.WantedBy = [ "sockets.target" ];
  };

  # --- Wallpaper: swaybg on niri's background layer ---
  # A background layer surface is also what niri's xray blur shows behind the
  # bar's frosted panels. Change the picture here and rebuild.
  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Desktop wallpaper (swaybg)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg -m fill -i ${config.home.homeDirectory}/Pictures/overview.jpg";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # --- direnv + nix-direnv: auto-load the flake devShell per project ---
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Example user-level git identity (uncomment to manage declaratively):
  # programs.git = {
  #   enable = true;
  #   userName = "ocbk";
  #   userEmail = "skjennepreken@gmail.com";
  # };
}
