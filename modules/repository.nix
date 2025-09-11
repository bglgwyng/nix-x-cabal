{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  local-package = import ./local-package.nix { inherit lib; };
in
types.submodule ({ config, ... }: {
  options = {
    name = mkOption {
      type = types.str;
      description = "Repository name";
    };
    url = mkOption {
      type = types.nullOr types.str;
      description = "Repository URL";
      default = null;
    };
    packages = mkOption {
      type = types.nullOr (types.listOf local-package);
      description = "Packages or paths for local no-index repository.";
      default = null;
    };
    text = mkOption {
      type = types.str;
      description = "Repository configuration text";
      readOnly = true;
    };
  };
  config = {
    text =
      if config.url != null then
        ''url: ${config.url}''
      else
        assert config.packages != null;
        let
          # Compress each package as .tar.gz
          compressedPackages = map
            ({ name, version, src }:
              let name-version = "${name}-${version}";
              in
              {
                name = "${name-version}.tar.gz";
                path = pkgs.runCommand "${name-version}.tar.gz" { } ''
                  mkdir -p "${name-version}"
                  cp -r ${src}/* "${name-version}/"
                  tar -czf $out "${name-version}"
                '';
              })
            (config.packages);
          # Create linkFarm for no-index repository
          no-index-repository = pkgs.stdenv.mkDerivation
            {
              name = "no-index-repository-${config.name}";
              # TODO: use cabal-install from config
              buildInputs = [ pkgs.cabal-install ];
              dontUnpack = true;
              buildPhase = ''
                export CABAL_CONFIG=${pkgs.writeText "cabal-config" ''
                  repository ${config.name}
                    url: file+noindex://$out
                ''}
                mkdir -p $out
                cd $out

                ${lib.concatMapStringsSep "\n" (p: "cp ${p.path} ${p.name}") compressedPackages}
              
                cabal update
              '';
            };
        in
        ''url: file+noindex://${no-index-repository}'';
  };
})

