{ lib, pkgs, generate-noindex-cache, generate-secure-repo-index-cache }:
let
  inherit (lib) mkOption types;
  repository = import ./repository.nix { inherit lib pkgs; };
  make-noindex-repository = import ../lib/make-noindex-repository.nix { inherit pkgs lib generate-noindex-cache; };
in
types.submoduleWith {
  modules = [
    {
      options = {
        root = mkOption {
          type = types.path;
          description = "Root directory of the Haskell project. cabal.project must be in this directory.";
        };
        repositories = mkOption {
          type = types.attrsOf repository;
          description = "Repository configurations";
          default = { };
        };
        extra-cabal-config = mkOption {
          type = types.raw;
          description = "Cabal";
          default = "";
        };
        haskellPackages = mkOption {
          type = types.raw;
          description = "Nixpkgs Haskell packages";
          default = pkgs.haskellPackages;
        };
        extra-buildInputs = mkOption {
          type = types.listOf types.package;
          description = "Extra build inputs";
          default = [ ];
        };
        packages-overlays = mkOption {
          type = types.listOf (types.functionTo (types.functionTo types.attrs));
          description = "Overlays for packages";
          default = [ ];
        };
        cabal-config = mkOption {
          type = types.path;
          description = "Path to cabal config";
          readOnly = true;
        };
        cabal-dir = mkOption {
          type = types.package;
          description = "Cabal dir";
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
        ghc = mkOption {
          type = types.package;
          description = "GHC";
          readOnly = true;
        };
        cabal-install = mkOption {
          type = types.package;
          description = "Wrapped cabal-install with CABAL_DIR and CABAL_CONFIG";
          readOnly = true;
        };
      };
    }
    ({ config, ... }:
      let
        named-repositories = lib.mapAttrsToList (name: repository: repository // { inherit name; }) config.repositories;
        secure-remote-repositories = builtins.filter (repository: repository.type == "secure") named-repositories;
        noindex-repositories = builtins.filter (repository: repository.type == "no-index") named-repositories;

        secure-remote-repositories-by-url =
          let
            grouped-by-url = lib.groupBy (item: item.url) secure-remote-repositories;

            duplicate-urls = builtins.attrNames (lib.filterAttrs (url: repos: builtins.length repos > 1) grouped-by-url);

            # Throw error if duplicates exist
          in
          lib.throwIf (builtins.length duplicate-urls > 0)
            "Duplicate repository URLs found: ${lib.concatStringsSep ", " duplicate-urls}. Each repository URL must be unique."
            (builtins.mapAttrs (_: builtins.head) grouped-by-url);
        get-cabal-metadata =
          let
            indices = lib.mapAttrs
              (_: repo: pkgs.runCommand repo.name { } ''
                mkdir $out
                tar -xzf ${repo.index} -C $out
              '')
              secure-remote-repositories-by-url;
          in
          { remote-url, name, version }:
          "${indices.${remote-url}}/${name}/${version}/${name}.cabal";
        cabal-metadata-index = import ../lib/make-cabal-metadata-index.nix {
          inherit pkgs lib secure-remote-repositories;
        };

        packages = import ../lib/packages-from-plan-json.nix {
          inherit pkgs;
          haskellPackages = config.haskellPackages;
          # Read plan.json with proper dependency tracking
          plan-json = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile (config.plan-json)));
          overlays = config.packages-overlays;
          # `get-local-package-deps` is used to recover the dependencies of local packages that lost their dependencies via `unsafeDiscardStringContext`
          # `cabal-install` depends on local repositories, so that letting local packages depends on `cabal-install` is enough
          # TODO: let each local package depends on the exact package source derivation
          get-local-package-deps = (name: version: [ config.cabal-install ]);
          inherit get-cabal-metadata;
        };
      in
      {
        config = {
          cabal-dir = pkgs.callPackage ../lib/make-cabal-dir.nix {
            inherit secure-remote-repositories; make-secure-repo-index-cache = generate-secure-repo-index-cache;
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
                    url: file+noindex://${make-noindex-repository repository}
                '')
                noindex-repositories
              ++ [ "with-compiler: ${config.haskellPackages.ghc}/bin/ghc" ]
              ++ (lib.optional (config.extra-cabal-config != "") config.extra-cabal-config)
            )
          );
          cabal-install = pkgs.symlinkJoin {
            name = "cabal-install";
            paths = [ config.haskellPackages.cabal-install ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/cabal \
                --set CABAL_CONFIG ${config.cabal-config} \
                --set CABAL_DIR "${config.cabal-dir}"
            '';
          };
          plan-json = pkgs.stdenv.mkDerivation {
            name = "plan.json";
            src = config.root;
            buildInputs = config.extra-buildInputs;
            buildCommand = ''
              MYTMP="$(mktemp -d)"
              trap 'rm -rf -- "$MYTMP"' EXIT
              
              ${config.cabal-install}/bin/cabal build all \
                --project-dir=$src \
                --dry-run \
                --builddir=$MYTMP \
                --offline

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
