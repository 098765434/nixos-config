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
    # modules, and auto-configures its binary cache (so niri isn't compiled
    # locally). We follow our nixpkgs to avoid a second copy.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, niri, ... }@inputs:
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
