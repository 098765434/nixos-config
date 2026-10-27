{
  description = "ocbk's NixOS + niri configuration";

  inputs = {
    # Pinned to the 26.05 stable channel (matches system.stateVersion). Update
    # with `nix flake update` (bumps flake.lock) then `nixos-rebuild switch`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # Make home-manager use the exact same nixpkgs as the system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning + LUKS + btrfs (see modules/disk.nix).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri compositor: newer than nixpkgs, provides the NixOS + home-manager
    # modules, and auto-configures its binary cache. Intentionally does NOT
    # follow our nixpkgs — the niri.cachix.org cache is built against niri-flake's
    # own pinned nixpkgs, so following would force niri to compile locally (and
    # can break eval when it needs a package version our nixpkgs dropped).
    niri.url = "github:sodiboo/niri-flake";

    # Secure Boot (signed boot chain) — completes the LUKS+TPM2 story.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # amane: Rust framework for building Wayland desktop shells. The CLI is
    # wrapped with its own Rust toolchain + wayland/pam/vulkan libs, so it can
    # rebuild the user shell at ~/.config/amane without a nixos-rebuild.
    amane = {
      url = "github:MystiaFin/amane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri fork with live gesture-progress IPC events (see the fork's
    # niri-gesture-ipc-spec.md). A public GitHub fork of YaLTeR/niri; used as
    # programs.niri.package in modules/desktop.nix. Pinned to the fork branch —
    # bump with `nix flake update niri-fork`. For local hacking, override with
    # `--override-input niri-fork path:$HOME/Projects/desktop/niri`. Follows our
    # nixpkgs so it builds against the same package set as the rest of the system.
    niri-fork = {
      url = "github:098765434/niri/ocbk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # amane-shell: the custom Wayland bar (depends on the amane fork via a git
    # dependency). Installed + run as a systemd user service in ./home/home.nix.
    # Bump with `nix flake update amane-shell`; local override:
    # `--override-input amane-shell path:$HOME/Projects/desktop/shell`.
    amane-shell = {
      url = "github:098765434/amane-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, niri, lanzaboote, amane, niri-fork, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Build/switch with:
      #   sudo nixos-rebuild switch --flake .#nixos-niri
      nixosConfigurations.nixos-niri = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix

          # Record the commit each generation was built from (`-dirty` when
          # the tree had uncommitted changes): `nixos-version --json` shows it,
          # and Shell Settings compares it with HEAD to say whether the
          # running system is up to date.
          { system.configurationRevision = self.rev or self.dirtyRev or null; }

          # Declarative disk layout (LUKS + btrfs).
          disko.nixosModules.disko

          # niri module (programs.niri + binary cache).
          niri.nixosModules.niri

          # Secure Boot module (inert until boot.lanzaboote.enable; see modules/security.nix).
          lanzaboote.nixosModules.lanzaboote

          # home-manager as a NixOS module so one rebuild does both.
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.ocbk = import ./home/home.nix;
          }
        ];
      };

      # What Shell Settings reads: every setting in managed/registry.nix with
      # its effective value, the option's type, default and description, and
      # the repo files that set it (`modules/managed.nix` when it's ours).
      #   nix eval --json .#amaneSettings
      amaneSettings =
        let
          lib = nixpkgs.lib;
          sys = self.nixosConfigurations.nixos-niri;
          registry = import ./managed/registry.nix;
          # the flake is copied to the store, so its files show as /nix/store/…-source/<file>
          strip = file:
            let m = builtins.match "/nix/store/[a-z0-9]{32}-source/(.*)" file;
            in if m == null then file else builtins.head m;
          # where a repo file defines an option, to the line: the module
          # is loaded again with its arguments and the attribute's position
          # read off it. null when the module's shape hides it (a mkMerge,
          # a let), and Settings then says to edit by hand.
          moduleArgs = sys._module.args // (sys._module.specialArgs or { })
            // { inherit (sys) config options pkgs; inherit lib; };
          loaded = file:
            let
              m = import file;
              called = if builtins.isFunction m
                then m (builtins.intersectAttrs (builtins.functionArgs m) moduleArgs)
                else m;
            in called.config or called;
          position = path: file:
            let
              r = builtins.tryEval (
                let
                  parent = lib.attrByPath (lib.init path) { } (loaded file);
                  pos = builtins.unsafeGetAttrPos (lib.last path) parent;
                in if pos == null then null else { file = strip pos.file; line = pos.line; });
            in if r.success then r.value else null;
          one = r:
            let
              opt = lib.getAttrFromPath r.path sys.options;
              # only real definitions: an unset option's default counts as one
              # at its declaration, at mkOptionDefault's priority (1500)
              defs = if (opt.highestPrio or 0) >= 1500 then [ ] else opt.definitionsWithLocations;
              elsewhere = builtins.filter
                (d: lib.hasPrefix "${self}/" d.file && strip d.file != "modules/managed.nix") defs;
            in r // {
              value = lib.getAttrFromPath r.path sys.config;
              default = opt.default or null;
              type = opt.type.description;
              description = opt.description or "";
              setIn = map (d: strip d.file) defs;
              setAt = builtins.filter (p: p != null) (map (d: position r.path d.file) elsewhere);
            };
          # a package's name without instantiating it; the odd one that
          # can't say is "?"
          safe = e: let r = builtins.tryEval e; in if r.success then r.value else "?";
        in {
          host = "nixos-niri";
          revision = self.rev or self.dirtyRev or null;
          entries = map one registry;
          # what this repo's files install system-wide (not NixOS's own
          # defaults), each with the file that lists it, for the Apps page
          systemPackages =
            let
              defs = sys.options.environment.systemPackages.definitionsWithLocations;
              ours = builtins.filter (d: lib.hasPrefix "${self}/" d.file) defs;
              named = file: p: {
                name = safe (p.pname or p.name or "?");
                version = safe (p.version or "");
                inherit file;
              };
            in builtins.concatMap (d: map (named (strip d.file)) d.value) ours;
        };

      # Per-project dev toolchain: `nix develop` (or direnv) drops you into a
      # shell with Rust + JDK, keeping them off the global system.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          rustc
          cargo
          rust-analyzer
          clippy
          jdk17
        ];
      };
    };
}
