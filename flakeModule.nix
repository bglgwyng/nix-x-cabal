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
      (
        let
          inherit (nix-x-cabal-utils.packages.${system}) generate-noindex-cache generate-secure-repo-index-cache;
          haskell-project = import ./modules/haskell-project.nix {
            inherit lib pkgs generate-secure-repo-index-cache generate-noindex-cache;
          };
        in
        {
          options = {
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
