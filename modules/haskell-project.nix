{ lib, pkgs, cabal }:
let
  inherit (lib) mkOption types;
in
types.submoduleWith {
  modules = [
    {
      options = {
        root = mkOption {
          type = types.path;
          description = "Root directory of the Haskell project. cabal.project must be in this directory.";
        };
        haskellPackages = mkOption {
          type = types.lazyAttrsOf types.raw;
          description = "Haskell package set to use";
          default = pkgs.haskellPackages;
        };
        generate-plan-json = mkOption {
          type = types.raw;
          description = "App to generate plan.json for this project";
          readOnly = true;
        };
        packages = mkOption {
          type = types.lazyAttrsOf types.raw;
          description = "Packages configured from plan.json";
          readOnly = true;
        };
        global-packages = mkOption {
          type = types.lazyAttrsOf types.raw;
          description = "Global Packages configured from plan.json";
          readOnly = true;
        };
        local-packages = mkOption {
          type = types.lazyAttrsOf types.raw;
          description = "Local Packages configured from plan.json";
          readOnly = true;
        };
        plan-json = mkOption {
          type = types.path;
          description = "Path to plan.json";
          readOnly = true;
        };
        cabal-install = mkOption {
          type = types.package;
          description = "Cabal";
        };
        ghc = mkOption {
          type = types.package;
          description = "GHC";
          readOnly = true;
        };
      };
    }
    ({ config, ... }:
      let
        packages = import ../lib/packages-from-plan-json.nix {
          inherit pkgs;
          haskellPackages = config.haskellPackages;
          # TODO: remove `unsafeDiscardStringContext`
          plan-json = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile config.plan-json));
        };
      in
      {
        config = {
          plan-json = pkgs.stdenv.mkDerivation {
            name = "plan.json";
            src = config.root;
            buildInputs = [ config.cabal-install ];
            buildCommand = ''
              MYTMP="$(mktemp -d)"
              trap 'rm -rf -- "$MYTMP"' EXIT

              cabal build all \
                --project-dir=$src \
                --dry-run \
                --builddir=$MYTMP

              cp $MYTMP/cache/plan.json $out
            '';
          };
          packages = packages.global-packages // packages.local-packages;
          global-packages = packages.global-packages;
          local-packages = packages.local-packages;
          ghc = config.haskellPackages.ghcWithPackages (_: builtins.attrValues config.global-packages);
        };
      })
  ];
}
