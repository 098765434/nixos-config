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

  # Encrypted DNS via systemd-resolved + DNS-over-TLS. "opportunistic" uses TLS
  # when the resolver supports it and falls back otherwise (won't break networks
  # that block port 853). Tailscale MagicDNS integrates with resolved cleanly.
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    # Encrypted fallbacks (Cloudflare + Quad9), used when the network provides none.
    fallbackDns = [
      "1.1.1.1#cloudflare-dns.com"
      "1.0.0.1#cloudflare-dns.com"
      "9.9.9.9#dns.quad9.net"
    ];
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
