# System services: networking extras, secrets, file-manager backend.
{ config, pkgs, ... }:

{
  # Tailscale VPN (run `sudo tailscale up` once after install to authenticate).
  services.tailscale.enable = true;

  # SSH server.
  services.openssh.enable = true;

  # mDNS / network discovery (KDE Connect, printers, .local names).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # GVFS — makes nautilus fully functional: trash, mounting, network shares.
  services.gvfs.enable = true;

  # GNOME keyring — secret storage for apps (vscode, Bitwarden, NM secrets),
  # unlocked automatically at login via the greetd PAM service.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Sunshine game-streaming host — enable on the real machine when you want it.
  # services.sunshine = {
  #   enable = true;
  #   openFirewall = true;
  #   capSysAdmin = true;   # required for Wayland screen capture
  # };
}
