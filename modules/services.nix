# System services: networking extras, secrets, file-manager backend.
{ config, lib, pkgs, ... }:

{
  # Tailscale VPN (run `sudo tailscale up` once after install to authenticate).
  # Switched on as `tailscale` in managed/settings.json (Shell Settings).

  # SSH server: `openssh` in managed/settings.json (Shell Settings → Services),
  # with `sshdOnDemand` keeping it installed but not started at boot, to keep
  # idle RAM down: `sudo systemctl start sshd` (or Start there) when needed.

  # Syncthing — continuously syncs the Obsidian vault with the "pi5" server.
  # DECLARATIVE: the devices/folders below are the source of truth. With
  # overrideDevices/overrideFolders (default true) any device or folder added in
  # the web UI is wiped on the next rebuild — manage sync topology HERE, not the
  # GUI. On a fresh install this pulls the whole vault down from pi5, so it also
  # doubles as the vault's restore path.
  # Switched on as `syncthing` in managed/settings.json (Shell Settings).
  services.syncthing = {
    user = "ocbk";
    group = "users";
    configDir = "/home/ocbk/.config/syncthing";
    dataDir = "/home/ocbk";                  # base for any relative folder paths
    openDefaultPorts = true;                 # 22000 tcp+udp (sync), 21027 udp (discovery)
    guiAddress = "127.0.0.1:8384";           # admin UI stays loopback-only
    settings = {
      devices.pi5.id =
        "RAZCYCW-SAZHSLR-AQIMHNO-ZVDGZTW-DZTVXIR-USOFO57-45YICWG-7S4ZKQF";
      folders."obsidian-vault" = {
        label = "Obsidian Vault";
        path = "/home/ocbk/obsidian/MyVault";
        type = "sendreceive";
        devices = [ "pi5" ];
      };
    };
  };

  # ---------------------------------------------------------------------------
  # On-demand "cloud" mount of the Debian desktop's home over Tailscale.
  # ---------------------------------------------------------------------------
  # rclone's SFTP backend mounts ocbk@debian:/home/ocbk at /home/ocbk/Cloud.
  # With --vfs-cache-mode full, files show as a normal folder and are fetched on
  # access (Dropbox "files on demand" style) — nothing extra runs on the desktop
  # beyond its existing SSH server. Transport is authenticated/encrypted by
  # Tailscale (WireGuard), so no inbound firewall hole is needed on this laptop.
  #
  # DESKTOP SIDE (run once, on `debian`):
  #   1. Ensure sshd is running and reachable over Tailscale.
  #   2. Authorize this laptop's key:
  #        mkdir -p ~/.ssh && chmod 700 ~/.ssh
  #        echo '<laptop /home/ocbk/.ssh/id_ed25519.pub>' >> ~/.ssh/authorized_keys
  #        chmod 600 ~/.ssh/authorized_keys
  #
  # LAPTOP SIDE: /home/ocbk/.ssh/id_ed25519 must exist (carry the keypair over
  # from the old install, or generate one and authorize its .pub on the desktop).
  # Until it does, the service just retries.
  #
  # Runs as root so it can mount without a setuid-fusermount wrapper; --allow-other
  # plus --uid/--gid present the files as user ocbk (uid 1000 / group users=100).
  programs.fuse.userAllowOther = true;

  systemd.services.rclone-desktop = {
    description = "rclone mount: debian desktop home (SFTP/Tailscale) -> /home/ocbk/Cloud";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.fuse3 ];   # rclone needs fusermount3 on PATH to mount
    environment = {
      RCLONE_CONFIG_DESKTOP_TYPE = "sftp";
      RCLONE_CONFIG_DESKTOP_HOST = "debian.tail8c36e9.ts.net";
      RCLONE_CONFIG_DESKTOP_USER = "ocbk";
      RCLONE_CONFIG_DESKTOP_KEY_FILE = "/home/ocbk/.ssh/id_ed25519";
      RCLONE_CONFIG_DESKTOP_SHELL_TYPE = "unix";
    };
    serviceConfig = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/ocbk/Cloud";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount desktop:/home/ocbk /home/ocbk/Cloud \
          --allow-other \
          --uid 1000 --gid 100 --umask 077 \
          --vfs-cache-mode full \
          --vfs-cache-max-size 5G \
          --vfs-cache-max-age 168h \
          --dir-cache-time 24h \
          --attr-timeout 1s
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u /home/ocbk/Cloud";
      Restart = "on-failure";
      RestartSec = 15;
    };
  };

  # mDNS / network discovery (KDE Connect, printers, .local names). Switched
  # on as `avahi` in managed/settings.json (Shell Settings); `avahiOnDemand`
  # keeps it from starting at boot (its socket still starts it on the first
  # .local lookup or printer/network browse).
  services.avahi = {
    nssmdns4 = true;
    openFirewall = true;
  };

  # Encrypted DNS via systemd-resolved + DNS-over-TLS. "opportunistic" uses TLS
  # when the resolver supports it and falls back otherwise (won't break networks
  # that block port 853). Tailscale MagicDNS integrates with resolved cleanly.
  services.resolved = {
    enable = true;
    # 26.05: dnssec/dnsovertls/fallbackDns were folded into settings.Resolve.*.
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNSOverTLS = "opportunistic";
      # Encrypted fallbacks (Cloudflare + Quad9), used when the network provides none.
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
      ];
    };
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
