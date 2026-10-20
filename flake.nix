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
    # niri-gesture-ipc-spec.md). Built from local source via the fork's own
    # flake (buildRustPackage with cargoLock), and used as programs.niri.package
    # in modules/desktop.nix. Only committed changes on the fork are picked up:
    # commit on the fork before `nixos-rebuild`. Follows our nixpkgs so it builds
    # against the same package set as the rest of the system.
    niri-fork = {
      url = "git+file:///home/ocbk/Projects/desktop/niri-fork";
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
