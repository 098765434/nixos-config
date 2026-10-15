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

1. **Set the target disk** in `modules/disk.nix` (`device = …`): `/dev/vda` in a
   QEMU VM, your real disk (e.g. `/dev/nvme0n1`) on the laptop. `lsblk` to confirm.
   ⚠️ disko **erases** that disk.
2. **Partition + encrypt + format + mount** (prompts for the LUKS passphrase):
   ```
   sudo nix --experimental-features "nix-command flakes" run \
     github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake .#nixos-niri
   ```
3. **Generate hardware config without filesystems** (disko owns those), then copy
   it into this repo next to `flake.nix`:
   ```
   sudo nixos-generate-config --no-filesystems --root /mnt
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

## TODO / future

- Harden the password: replace `initialPassword` in `configuration.nix` with a
  `hashedPassword` (`mkpasswd -m sha-512`).
- Add the Arch fonts (Cascadia Code NF, Atkinson Hyperlegible, Material Symbols, Rubik).
- Package the `amane` / `caelestia` quickshell shell (currently stubbed by
  waybar + wofi + mako).
- Optional: encrypted swap partition if you want hibernation (currently zram only).
