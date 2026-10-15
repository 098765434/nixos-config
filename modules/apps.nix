# System-wide packages. (Unfree is allowed in configuration.nix.)
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- niri session companions (referenced by niri config.kdl) ---
    foot             # terminal (Mod+Return / Mod+T)
    wofi             # launcher (Mod+D)
    swaylock         # screen locker (Super+Alt+L)
    waybar           # status bar
    hypridle         # idle management (needs a hypridle.conf to act)
    playerctl        # media keys
    brightnessctl    # brightness keys
    wl-clipboard     # Wayland clipboard (also feeds cliphist)
    xwayland-satellite  # run X11 apps under niri

    # --- niri desktop niceties ---
    blueman          # Bluetooth GUI (service enabled in desktop.nix)
    pwvucontrol      # PipeWire volume GUI
    networkmanagerapplet  # nm-applet tray + nm-connection-editor
    slurp            # region selection (screenshots/screencasts)
    cliphist         # clipboard history (spawned in niri config)
    wlsunset         # night light / color temperature

    # --- general CLI ---
    git
    wget
    curl             # also used by update-artcraft.sh
    openssl          # also used by update-artcraft.sh (hashing)
    htop

    # --- desktop essentials ---
    hyprpolkitagent  # polkit agent (run by the systemd service in desktop.nix)
    mako             # notification daemon (spawned in niri config)
    grim             # screenshot capture backend
    wtype            # synthetic keyboard input (Wayland)
    cava             # audio visualizer
    libqalculate     # `qalc` calculator

    # --- CLI & dev tools ---
    bat
    fd
    fzf
    ripgrep
    github-cli       # gh
    neovim
    rbw              # Bitwarden CLI
    bitwarden-desktop
    # Toolchains: gcc + python3 kept global (python3 also feeds update-artcraft.sh).
    # Rust (rustc/cargo) and the JDK live in the flake devShell — run `nix develop`
    # (or let direnv auto-load it) per project instead of polluting the system.
    gcc
    python3

    # --- GUI apps ---
    # Browser: Zen (not in nixpkgs) is installed via Flatpak — see desktop.nix.
    nautilus
    gnome-disk-utility
    gnome-calculator
    loupe                 # image viewer
    evince                # PDF viewer
    vscode
    zed-editor
    obsidian
    mission-center        # system/resource monitor
    heroic                # Epic/GOG/Amazon games launcher (Steam via gaming.nix)
    youtube-music         # YouTube Music desktop app

    # --- hardware helpers ---
    ddcutil               # external-monitor brightness over DDC/CI
  ];
}
