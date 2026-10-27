# ocbk's NixOS + niri configuration

Flake-based NixOS for an AMD Ryzen AI 7 / Radeon 860M laptop running the
**niri** scrolling compositor. Encrypted (LUKS2 + btrfs + TPM2), modular, with
home-manager for dotfiles.

## Layout

```
flake.nix              inputs (nixpkgs, home-manager, disko, niri-flake) + devShell
configuration.nix      core: boot, networking, locale, user, nix
modules/
  disk.nix             disko: GPT + ESP + LUKS2 + btrfs subvolumes (+ install notes)
  hardware.nix         firmware, AMD GPU, bluetooth, fprintd, power, audio, i2c
  desktop.nix          niri, greetd, portals, polkit, flatpak, fonts
  gaming.nix           steam, gamemode
  services.nix         tailscale, ssh, avahi, gvfs, gnome-keyring
  apps.nix             system packages
  managed.nix          settings Shell Settings owns (reads managed/settings.json) + its activate helper
managed/
  registry.nix         which settings Shell Settings may own, and their NixOS option paths
  settings.json        their values — written by Shell Settings, or by hand
home/home.nix          home-manager: niri/waybar/foot/wofi/amane-shell/hypridle/direnv
niri/config.kdl        niri config (symlinked into ~/.config via mkOutOfStoreSymlink — edit live, no rebuild)
waybar/                waybar config + style (also symlinked live; adapted from mechakotik/dots)
artcraft.nix           ArtCraft apps (vectorcraft/figcraft/photocraft/designcraft)
artcraft-sources.json  pinned ArtCraft versions + hashes
update-artcraft.sh     refresh ArtCraft to latest releases
```

## Install (fresh machine, from the NixOS installer)

Follow these in order. Every command is run **in the NixOS live USB**, in a
terminal, unless it says otherwise. The config is already validated
(`nix eval` of the full system passes) and inputs are pinned in `flake.lock`, so
there are no decisions to make here beyond the disk and the LUKS passphrase.

**Boot the installer:** insert the NixOS 26.05 **graphical** USB, power on, tap
**F12** at the Lenovo splash, choose the USB stick. When the desktop loads,
connect Wi-Fi from the top-right network menu, then open a terminal (Console).

### 1. Clone this repo

The repo is made **public** for the install, so cloning needs no login — just:

```
git clone https://github.com/098765434/nixos-config.git
cd nixos-config
git log --oneline -1
```

The last command **must** print `9a9deb4 Fix 26.05 eval errors …` or a *newer*
commit on top. If it shows an older or unknown commit, stop — you cloned the
wrong revision.

> Set the repo back to **private** afterward: GitHub → the repo → Settings →
> General → Change repository visibility. (If you'd rather keep it private during
> the install, clone over HTTPS and paste a fine-grained PAT — Contents: read —
> as the password; the token must be on the live session's clipboard to paste
> with Ctrl+Shift+V.)

### 2. Confirm the target disk

```
lsblk
grep device modules/disk.nix
```

`device` is preset to this laptop's internal NVMe by its stable
`/dev/disk/by-id/…` path (a ~238 G WD SN7100S). Confirm `lsblk` shows that same
disk as the internal one.

> ⚠️ **The next step ERASES that entire disk** — every partition, no prompt,
> no undo. Make sure anything you need is already backed up elsewhere.
> On a *different* machine you must edit `device` to match and regenerate
> `hardware-configuration.nix` (see the note in `modules/disk.nix`).

### 3. Partition, encrypt, format, mount

```
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount --flake .#nixos-niri
```

It prompts you to **set a NEW LUKS passphrase** (typed twice, with no characters
shown). This becomes the disk-encryption password you enter at **every boot**:

- Choose something strong you will not forget — **there is no recovery** if lost.
- The boot-time unlock prompt uses a **US-QWERTY** layout, so avoid characters
  that move around on the Norwegian layout, or you may not be able to retype it.

### 4. Install

```
sudo nixos-install --flake .#nixos-niri
```

This builds the whole system (a large first-time download). If it ever fails on
an ArtCraft app (stale AppImage hash/URL), run `./update-artcraft.sh` and re-run
the same command.

When it finishes it asks you to set a root password — you can just press Enter
(root login stays disabled); your user password is handled at first boot below.

### 5. Reboot

```
reboot
```

Remove the USB. At boot, enter the LUKS passphrase from step 3. You'll reach the
**tuigreet** greeter — log in as **`ocbk`** (temporary password: `nixos`),
session **niri**.

## First boot — finish setup (do these in order)

1. **Set a real password** (replaces the `nixos` default):
   ```
   passwd
   ```

2. **Join the tailnet** (needed for the restore below and for Syncthing/rclone):
   ```
   sudo tailscale up
   ```

3. **Restore the SSH keys + GNOME Connections** saved before the wipe. They live
   on the `debian` desktop at `~/nixos-migration-YYYYMMDD/`. Because the SSH key
   you'd need to pull them is *inside* that backup, **push from `debian`** instead
   of pulling:
   ```
   # run ON the debian desktop (enter this machine's new password when asked):
   scp -r ~/nixos-migration-* ocbk@nixos:~/
   ```
   ```
   # then back on THIS machine:
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   cp ~/nixos-migration-*/ssh/* ~/.ssh/ && chmod 600 ~/.ssh/id_*
   cp ~/nixos-migration-*/config/connections.db ~/.config/
   ```

4. **Supply the Wi-Fi password** for the declarative profile. It is read from a
   root-only file that is never in the repo:
   ```
   sudo install -m 600 /dev/stdin /etc/nm-secrets.env <<'EOF'
   HOME_WIFI_PSK=your-actual-wifi-password
   EOF
   sudo systemctl restart NetworkManager
   ```

5. **Verify sync + cloud** (both start automatically):
   - Syncthing pulls the Obsidian vault from `pi5` — UI at `http://127.0.0.1:8384`.
   - `~/Cloud` mounts the debian desktop over Tailscale once the SSH key (step 3)
     is in place: `systemctl status rclone-desktop` should be *active (running)*,
     and `ls ~/Cloud` should list the desktop's home.

### Optional hardening (once everything works)

- **TPM2 auto-unlock** — unlock the disk without typing the passphrase each boot
  (the passphrase still works as a fallback). Use the LUKS **partition**:
  ```
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/nvme0n1p2
  ```
- **Secure Boot (lanzaboote)** — full runbook in `modules/security.nix`.

## Daily use

```
sudo nixos-rebuild switch --flake .#nixos-niri   # apply changes
nix flake update                                 # update all inputs (then rebuild)
nix develop                                       # Rust/JDK dev shell (or via direnv)
./update-artcraft.sh                              # bump ArtCraft apps to latest
```

See [CHEATSHEET.md](CHEATSHEET.md) for rollback, hot-reload, GC, installing from GitHub, and other common operations.

Zen browser (not in nixpkgs) via Flatpak after first boot:
```
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub app.zen_browser.zen
```

## Post-build checks

- `niri validate ~/.config/niri/config.kdl`
- `systemctl --user status hyprpolkitagent amane-shell hypridle`
- waybar shows workspaces (confirms nixpkgs waybar has the niri module)
- `nix develop` gives `rustc`, `cargo`, `java`

## Known verification points (unevaluated until first build)

- Package attrs exist on 26.05: `pwvucontrol`, `youtube-music`,
  `networkmanagerapplet`, `bitwarden-desktop`, `zed-editor`, `mission-center`,
  `nerd-fonts.{jetbrains-mono,mononoki}`.
- `home-manager` `release-26.05` branch exists (else track `master`).
- waybar's `niri/workspaces` is compiled in nixpkgs (else override/drop the module).
- `security.pam.services.greetd.enableGnomeKeyring` is valid on 26.05.
- niri-flake coexists with any nixpkgs `programs.niri` (niri-flake handles this;
  if it errors, see the niri-flake README).

## Security & privacy

- **Full-disk encryption**: LUKS2 + btrfs, passphrase + TPM2 auto-unlock (see
  `modules/disk.nix`).
- **Auto screen-lock**: hypridle locks (swaylock) after 4 min idle and before
  sleep; `Super+Alt+L` locks on demand. swaylock auth via a system PAM entry.
- **Network privacy**: Wi-Fi MAC randomization (`networking.networkmanager.wifi.macAddress`)
  and encrypted DNS over TLS via systemd-resolved (`modules/services.nix`).
- **Secure Boot (lanzaboote)** — *staged, enable after install*. Completes the
  LUKS+TPM2 chain by signing the boot path. Runbook is in `modules/security.nix`:
  install → `sbctl create-keys` → uncomment the lanzaboote block + rebuild →
  firmware Setup Mode → `sbctl enroll-keys --microsoft` → enable Secure Boot.

## TODO / future

- Harden the password: replace `initialPassword` in `configuration.nix` with a
  `hashedPassword` (`mkpasswd -m sha-512`).
- Add the Arch fonts (Cascadia Code NF, Atkinson Hyperlegible, Material Symbols, Rubik).
- Package the `amane` / `caelestia` quickshell shell (currently stubbed by
  waybar + wofi + mako).
- Optional: encrypted swap partition if you want hibernation (currently zram only).

## Shell Settings

The shell's settings app has a **System** group that manages this repo. It never edits the
hand-written `.nix` files: it writes `managed/settings.json` (the keys are listed in
`managed/registry.nix`, and `modules/managed.nix` turns them into option definitions), builds
the system as your user, shows what changes, then activates it through polkit
(`amane-nixos-activate`, exit 2 on anything but a built NixOS system). After a successful
switch it commits **only** `managed/settings.json` as `settings: …` and never pushes. Undo one
with `git revert`; `nix eval --json .#amaneSettings` shows what Settings sees. Details:
amane-shell's `docs/integration/nixos.md`.
