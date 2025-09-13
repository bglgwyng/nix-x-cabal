{
  description = "Haskell packages from plan.json";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nix-x-cabal-utils.url = "github:bglgwyng/nix-x-cabal-utils";
  };

  outputs = inputs@{ flake-parts, nix-x-cabal-utils, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      flake = {
        flakeModule = import ./flakeModule.nix { inherit nix-x-cabal-utils; };
      };
    };
}
