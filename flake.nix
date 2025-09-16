{
  description = "Blessed shipping between Nix and Cabal";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nix-x-cabal-utils.url = "github:bglgwyng/nix-x-cabal-utils";
  };

  outputs = inputs@{ flake-parts, nixpkgs, nix-x-cabal-utils, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ flake-parts-lib, ... }: {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      flake = {
        flakeModule = import ./flakeModule.nix { inherit nix-x-cabal-utils; };
      };
      perSystem = { config, self', system, pkgs, lib, ... }: {
        packages = {
          docs =
            let
              # Import the flake module to extract options
              flakeModule = import ./flakeModule.nix { inherit (inputs) nix-x-cabal-utils; };

              eval = lib.evalModules {
                specialArgs = { inherit pkgs flake-parts-lib; };
                modules = [
                  flakeModule
                ];
              };
              optionsDoc = pkgs.nixosOptionsDoc {
                inherit (eval) options;
              };
            in
            pkgs.runCommand "options-doc.md" { } ''
              cat ${optionsDoc.optionsCommonMark} > $out
            '';
        };
      };
    });
}
