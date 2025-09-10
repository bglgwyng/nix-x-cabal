{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  options = {
    perSystem = mkPerSystemOption (
      { config, pkgs, ... }:
      let
        cabal = import ./modules/cabal.nix { inherit lib pkgs; };
        haskell-project = import ./modules/haskell-project.nix { inherit lib pkgs cabal; };
      in
      {
        options.cabals = lib.mkOption {
          type = lib.types.attrsOf cabal;
          description = "Cabals";
          default = { };
        };
        options.haskell-projects = lib.mkOption {
          type = lib.types.attrsOf haskell-project;
          description = "Haskell projects";
          default = { };
        };
      }
    );
  };
}
