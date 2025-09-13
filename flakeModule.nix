{ nix-x-cabal-utils }:
rest@{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  options = {
    perSystem = mkPerSystemOption (
      rest@{ config, pkgs, system, inputs', ... }:
      # builtins.trace (buil' ? nixpkgs)
      (
        let
          inherit (nix-x-cabal-utils.packages.${system}) generate-noindex-cache generate-secure-repo-index-cache;
          cabal = builtins.import ./modules/cabal.nix {
            inherit lib pkgs;
            inherit nix-x-cabal-utils;
          };
          haskell-project = import ./modules/haskell-project.nix { inherit lib pkgs cabal; };
        in
        {
          options = {
            cabals = lib.mkOption {
              type = lib.types.attrsOf cabal;
              description = "Cabals";
              default = { };
            };
            haskell-projects = lib.mkOption {
              type = lib.types.attrsOf haskell-project;
              description = "Haskell projects";
              default = { };
            };
          };
        }
      )
    );
  };
}
