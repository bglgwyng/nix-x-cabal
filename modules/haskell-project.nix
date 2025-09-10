{ lib, pkgs }:
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
        ghc = mkOption {
          type = types.package;
          description = "GHC with packages to use";
          readOnly = true;
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
        cabal-config = mkOption {
          type = types.path;
          description = "Path to cabal config";
          default = pkgs.writeText "cabal-config" ''
            repository hackage.haskell.org
              url: http://hackage.haskell.org/
          '';
        };
        cabal-dir-sha256 = mkOption {
          type = types.str;
          description = "SHA256 of cabal dir";
        };
        cabal-dir = mkOption {
          type = types.path;
          description = "Path to cabal dir";
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
          cabal-dir = pkgs.callPackage ../lib/generate-cabal-dir.nix {
            cabal-config = config.cabal-config;
            sha256 = config.cabal-dir-sha256;
          };
          plan-json = pkgs.stdenv.mkDerivation {
            name = "plan.json";
            src = config.root;
            buildInputs = [ config.haskellPackages.cabal-install config.haskellPackages.ghc ];
            buildCommand = ''
              export CABAL_CONFIG=${config.cabal-config}
              export CABAL_DIR=${config.cabal-dir}
            
              MYTMP="$(mktemp -d)"
              trap 'rm -rf -- "$MYTMP"' EXIT

              cabal build all \
                --project-dir=$src \
                --dry-run \
                --builddir=$MYTMP \
                --with-compiler=ghc

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
