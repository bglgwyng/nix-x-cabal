{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  repository = import ./repository.nix { inherit lib; };
in
types.submoduleWith {
  modules = [
    {
      options = {
        ghc = mkOption {
          type = types.package;
          description = "GHC to use";
          default = pkgs.ghc;
        };
        cabal-config = mkOption {
          type = types.path;
          description = "Path to cabal config";
          readOnly = true;

        };
        repositories = mkOption {
          type = types.attrsOf repository;
          description = "Repository configurations";
          default = { };
        };
        extra-cabal-config = mkOption {
          type = types.str;
          description = "Extra cabal config";
          default = "";
        };
        cabal-dir = mkOption {
          type = types.package;
          description = "Cabal dir";
          readOnly = true;
        };
        cabal-dir-sha256 = mkOption {
          type = types.str;
          description = "SHA256 of cabal dir";
        };
        cabal-install = mkOption {
          type = types.package;
          description = "Wrapped cabal-install with CABAL_DIR and CABAL_CONFIG";
          readOnly = true;
        };
        cabal-install-base = mkOption {
          type = types.package;
          description = "Base cabal-install";
          default = pkgs.cabal-install;
        };
      };
    }
    ({ config, ... }: {
      config = {
        cabal-dir = pkgs.callPackage ../lib/generate-cabal-dir.nix {
          inherit (config) cabal-config;
          sha256 = config.cabal-dir-sha256;
        };
        cabal-config = pkgs.writeText "cabal-config" (
          lib.concatStringsSep "\n" (
            (lib.mapAttrsToList
              (name: repo: ''
                repository ${name}
                  url: ${repo.url}
              '')
              config.repositories
            ) ++ [ "with-compiler: ${config.ghc}/bin/ghc" ]
            ++ (lib.optional (config.extra-cabal-config != "") config.extra-cabal-config)
          )
        );
        cabal-install = pkgs.symlinkJoin {
          name = "cabal-install-wrapped";
          paths = [ config.cabal-install-base ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/cabal \
              --set CABAL_DIR "${config.cabal-dir}" \
              --set CABAL_CONFIG "${config.cabal-config}"
          '';
        };
      };
    })
  ];
}

