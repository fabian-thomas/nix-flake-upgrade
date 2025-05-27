{
  description = "nix-flake-upgrade module and script. Pretty much system.autoUpgrade but with nicer commits for flake.lock changes.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs     = import nixpkgs { inherit system; };
      nix-flake-upgrade = pkgs.writeShellApplication {
        name = "nix-flake-upgrade";
        runtimeInputs = with pkgs; [
          gitMinimal openssh nix nh nvd
          coreutils gawk gnugrep
          # for hostname
          nettools
        ];
        text = builtins.readFile ./nix-flake-upgrade;
      };
    in
    rec {
      packages.nix-flake-upgrade = nix-flake-upgrade;

      apps.nix-flake-upgrade = {
        type    = "app";
        program = "${nix-flake-upgrade}/bin/nix-flake-upgrade";
      };

      defaultPackage = nix-flake-upgrade;
      defaultApp     = apps.nix-flake-upgrade;

      nixosModules.auto-upgrade-flake = (import ./auto-upgrade.nix { inherit nix-flake-upgrade; });
      nixosModule = nixosModules.auto-upgrade-flake;
    });
}
