{ nix-x-cabal-utils }:
{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  options = {
    perSystem = mkPerSystemOption (
      { config, pkgs, system, inputs', ... }:
      (
        let
          inherit (nix-x-cabal-utils.packages.${system}) generate-noindex-cache generate-secure-repo-index-cache;
          cabal-project = import ./modules/cabal-project.nix {
            inherit lib pkgs generate-secure-repo-index-cache generate-noindex-cache;
          };
        in
        {
          options = {
            cabal-projects = lib.mkOption {
              type = lib.types.attrsOf cabal-project;
              description = "Cabal projects";
              default = { };
            };
          };
        }
      )
    );
  };
}
