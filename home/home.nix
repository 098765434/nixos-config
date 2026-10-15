# home-manager configuration for user "ocbk".
#
# Manages your per-user dotfiles declaratively. Edit the sources in this repo
# and run `nixos-rebuild switch`; the files become read-only symlinks in
# ~/.config. `inputs` is passed through from the flake (extraSpecialArgs).
{ config, pkgs, inputs, ... }:

{
  imports = [
    # niri's home-manager module — lets us manage config.kdl with validation
    # against the installed niri version at build time.
    inputs.niri.homeModules.niri
  ];

  home.stateVersion = "26.05";

  # niri config (validated by the niri-flake module). Source of truth is the
  # KDL file in the repo; this reads it verbatim.
  programs.niri.config = builtins.readFile ../niri/config.kdl;

  # waybar — ship the raw config (adapted from mechakotik/dots) as-is.
  xdg.configFile = {
    "waybar/config".source = ../waybar/config;
    "waybar/style.css".source = ../waybar/style.css;
  };

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
      general.ignore_dbus_inhibit = false;
      listener = [
        {
          timeout = 180;                         # 3 min: dim OLED
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 300;                         # 5 min: DPMS off
          on-timeout = "niri msg action power-off-monitors";
          on-resume = "niri msg action power-on-monitors";
        }
      ];
    };
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
