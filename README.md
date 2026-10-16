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
  desktop.nix          niri, greetd, portals, polkit, flatpak, blueman, fonts
  gaming.nix           steam, gamemode
  services.nix         tailscale, ssh, avahi, gvfs, gnome-keyring
  apps.nix             system packages
home/home.nix          home-manager: niri/waybar/foot/wofi/mako/hypridle/direnv
niri/config.kdl        niri config (validated via niri-flake HM module)
waybar/                waybar config + style (adapted from mechakotik/dots)
artcraft.nix           ArtCraft apps (vectorcraft/figcraft/photocraft/designcraft)
artcraft-sources.json  pinned ArtCraft versions + hashes
update-artcraft.sh     refresh ArtCraft to latest releases
```

## Install (fresh machine, from the NixOS installer)

> **Flakes only see git-tracked files.** This directory must be a git repo with
> the files at least staged, or the flake ignores them:
> ```
> git init && git add -A
> ```

1. **Confirm the target disk** in `modules/disk.nix` (`device = …`): already set
   to this laptop's NVMe by its `/dev/disk/by-id/` path. `lsblk` to confirm.
   ⚠️ disko **erases** that disk. (In a QEMU VM, set `/dev/vda` instead.)
2. **Partition + encrypt + format + mount** (prompts for the LUKS passphrase):
   ```
   sudo nix --experimental-features "nix-command flakes" run \
     github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake .#nixos-niri
   ```
3. **`hardware-configuration.nix` is already committed** (hand-written for this
   machine). Optional: regenerate without filesystems (disko owns those) and
   diff — don't overwrite unless the diff reveals a gap:
   ```
   sudo nixos-generate-config --no-filesystems --root /mnt
   diff /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
   ```
4. **Install**:
   ```
   sudo nixos-install --flake .#nixos-niri
   ```
5. Reboot, enter the LUKS passphrase. Set a real password: `passwd`.
6. **Real hardware only — TPM2 auto-unlock** (use the LUKS *partition*):
   ```
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/nvme0n1p2
   ```

## Daily use

```
sudo nixos-rebuild switch --flake .#nixos-niri   # apply changes
nix flake update                                 # update all inputs (then rebuild)
nix develop                                       # Rust/JDK dev shell (or via direnv)
./update-artcraft.sh                              # bump ArtCraft apps to latest
```

Zen browser (not in nixpkgs) via Flatpak after first boot:
```
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub app.zen_browser.zen
```

## Post-build checks

- `niri validate ~/.config/niri/config.kdl`
- `systemctl --user status hyprpolkitagent mako hypridle`
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
