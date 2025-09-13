{ lib, pkgs, nix-x-cabal-utils, generate-secure-repo-index-cache, generate-noindex-cache }:
let
  inherit (lib) mkOption types;
  repository = import ./repository.nix { inherit lib pkgs; };
  generate-noindex-repository = import ../lib/generate-noindex-repository.nix { inherit pkgs lib generate-noindex-cache; };
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
    ({ config, ... }:
      let
        secure-remote-repositories = (builtins.filter (repository: repository.url != null) (builtins.attrValues config.repositories));
        noindex-repositories = (builtins.filter (repository: repository.packages != null) (builtins.attrValues config.repositories));
      in
      {
        config = {
          cabal-dir = pkgs.callPackage ../lib/generate-cabal-dir.nix {
            inherit secure-remote-repositories generate-secure-repo-index-cache;
          };
          cabal-config = pkgs.writeText "cabal-config" (
            lib.concatStringsSep "\n" (
              map
                (repository: ''
                  repository ${repository.name}
                    url: ${repository.url}
                '')
                secure-remote-repositories
              ++
              map
                (repository: ''
                  repository ${repository.name}
                    url: file+noindex://${generate-noindex-repository repository}
                '')
                noindex-repositories
              ++ [ "with-compiler: ${config.ghc}/bin/ghc" ]
              ++ (lib.optional (config.extra-cabal-config != "") config.extra-cabal-config)
            )
          );
          cabal-install = pkgs.symlinkJoin {
            name = "cabal-install-wrapped";
            paths = [ config.cabal-install-base ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/cabal \
                --set CABAL_CONFIG ${config.cabal-config} \
                --set CABAL_DIR "${config.cabal-dir}"
            '';
          };
        };
      })
  ];
}

