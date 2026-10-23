# Cheatsheet

Everything is run from `~/nixos-config` unless stated. Flake name is
`nixos-niri`; hostname is `nixos`.

## Rebuilds

```sh
sudo nixos-rebuild switch --flake .#nixos-niri    # apply + activate now
sudo nixos-rebuild test   --flake .#nixos-niri    # activate without making it the default boot entry
sudo nixos-rebuild boot   --flake .#nixos-niri    # queue for next boot, don't activate now
sudo nixos-rebuild build  --flake .#nixos-niri    # just evaluate + build, no activation
```

Add `--show-trace` to any of them when a Nix eval error is cryptic.

Plain `sudo nixos-rebuild switch` (no `--flake`) will fail with
`'nixos-config' not found` — that's the legacy channels path, which this
machine doesn't use.

## Updates

```sh
nix flake update                       # bump every input in flake.lock
nix flake update nixpkgs               # bump just one
./update-artcraft.sh                   # bump the four storytold AppImages in artcraft-sources.json
```

Each of these only changes a file (`flake.lock` or `artcraft-sources.json`).
Nothing takes effect until the next `nixos-rebuild switch`.

Updating a single ArtCraft app without the script: edit
`artcraft-sources.json`, change the `version`, replace the `hash` with
`sha256-0000000000000000000000000000000000000000000=`, rebuild — Nix prints
the real hash it got; paste that in and rebuild again.

## Rollback

```sh
sudo nixos-rebuild switch --rollback           # back to the previous generation
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
```

Or from the bootloader: pick an older NixOS generation at the GRUB/systemd-boot menu.

For a *config* rollback without changing generations, just:

```sh
git checkout flake.lock                        # or whichever file you want to revert
sudo nixos-rebuild switch --flake .#nixos-niri
```

## Hot-reload (no rebuild needed)

| Config | File | Reload |
|---|---|---|
| niri | `niri/config.kdl` | automatic on save |
| waybar | `waybar/config`, `waybar/style.css` | `pkill -SIGUSR2 waybar` |
| amane-shell (bar + notifications) | HM-managed via `home.nix` | needs rebuild |
| hypridle, swaylock, foot, wofi | HM-managed | needs rebuild |

The niri/waybar files are `mkOutOfStoreSymlink`'d at the repo, so editing
them live changes the live config.

Validate niri KDL before relying on the auto-reload: `niri validate ~/.config/niri/config.kdl`.

## Installing apps

**From nixpkgs** — add to `environment.systemPackages` in [modules/apps.nix](modules/apps.nix),
then rebuild.

**One-shot, no install** — `nix run nixpkgs#htop` or `nix shell nixpkgs#ripgrep -c rg --version`.

**From a GitHub flake** — add it as a flake input in [flake.nix](flake.nix):

```nix
inputs.foo.url = "github:owner/repo";
# then in a module:
environment.systemPackages = [ inputs.foo.packages.${pkgs.system}.default ];
```

Try it first with `nix run github:owner/repo` — no commit needed.

**From a GitHub Release AppImage** — follow the ArtCraft pattern in
[artcraft.nix](artcraft.nix): `pkgs.fetchurl` the asset, run it through
`appimageTools.extract` + `appimageTools.wrapType2`, and copy `usr/share/{applications,icons}`
into `$out/share` so the launcher sees it.

**Unpatched dynamic binaries** (random Linux `.tar.gz` releases) — `programs.nix-ld`
is enabled in [modules/desktop.nix](modules/desktop.nix), so most will just run.
For a one-off, `nix-shell -p steam-run --run 'steam-run ./the-binary'`.

**Static binaries** — drop in `~/.local/bin`. NixOS never touches your home,
so it survives rebuilds. Fine for scratch; migrate to a derivation if you
want it tracked.

**Flatpak** — Flatpak itself is already enabled (that's how Zen gets installed).
`flatpak install flathub app.foo.bar`.

## Dev shells

```sh
nix develop             # loads the flake's devShell (Rust + JDK)
nix develop nixpkgs#...  # ad-hoc shell from a flake
```

With direnv (enabled in [home/home.nix](home/home.nix)), drop a one-line
`.envrc` in a project — `use flake` — and the shell loads automatically on `cd`.

## Garbage collection / disk

```sh
nix-store --gc                                                      # drop unreferenced store paths
sudo nix-collect-garbage --delete-older-than 14d                    # also drop generations older than 14 days
sudo nix-collect-garbage -d                                         # drop ALL old generations (nothing to roll back to)
du -sh /nix/store                                                   # how big is the store
nix path-info -S $(which some-command)                              # closure size of one package
```

After a big GC, run `sudo nixos-rebuild boot --flake .#nixos-niri`
to refresh the boot entry (older ones are gone).

## Pushing commits

The `origin` remote is HTTPS, so plain `git push` prompts for a PAT. To stop
being asked every time, once:

```sh
git config --global credential.helper store
git push                       # enter the PAT; it's saved to ~/.git-credentials
```

Or switch to SSH: add an SSH key to GitHub, then
`git remote set-url origin git@github.com:098765434/nixos-config.git`.

## Zen Browser quirks

Zen is a Flatpak, so its file picker is sandboxed. To import something from
`/tmp` or the scratchpad, first copy it to `~/Downloads` (that path is
pre-granted). Or widen access once:

```sh
flatpak override --user --filesystem=home app.zen_browser.zen
```

Firefox-based browsers import HTML bookmarks into the **Bookmarks Menu**
folder, not the toolbar — open `Ctrl+Shift+O` to find them.

## Post-build sanity checks

```sh
niri validate ~/.config/niri/config.kdl
systemctl --user status hyprpolkitagent amane-shell hypridle
```
