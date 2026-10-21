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

  # --- Notifications: mako (replaces the niri `spawn-at-startup "mako"`) ---
  services.mako = {
    enable = true;
    settings = {
      font = "JetBrainsMono Nerd Font 10";
      default-timeout = 5000;
      background-color = "#232629";
      text-color = "#eff0f1";
      border-color = "#7fc8ff";
      border-radius = 8;
    };
  };

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
      listener = [
        {
          timeout = 180;                         # 3 min: dim OLED
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 240;                         # 4 min: lock the screen
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 300;                         # 5 min: DPMS off
          on-timeout = "niri msg action power-off-monitors";
          on-resume = "niri msg action power-on-monitors";
        }
      ];
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

  # --- Bar: amane-shell (custom niri taskbar) ---
  # Installed from the flake input and run as a user service bound to the niri
  # graphical session, so it starts on login and restarts on crash (logs via
  # `journalctl --user -u amane-shell`) — mirrors the mako/hypridle pattern and
  # replaces a niri `spawn-at-startup`. Default theme is dark; to switch, add
  # Environment = [ "AMANE_THEME=light" ] to Service below.
  # The bar's blur/rounding also needs its niri layer-rules: run
  # `~/Projects/desktop/shell/gen-layer-rules.sh ~/nixos-config/niri/config.kdl`.
  home.packages = [ inputs.amane-shell.packages.${pkgs.system}.default ];
  systemd.user.services.amane-shell = {
    Unit = {
      Description = "amane-shell bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.amane-shell.packages.${pkgs.system}.default}/bin/amane-shell";
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
