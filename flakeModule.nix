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
        haskell-project = import ./modules/haskell-project.nix { inherit lib pkgs; };
      in
      {
        options.haskell-projects = lib.mkOption {
          type = lib.types.attrsOf haskell-project;
          description = "Haskell projects";
          default = { };
        };
      }
    );
  };
}
