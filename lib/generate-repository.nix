# Repository utility functions
{ lib, pkgs, repository }:
if repository.url != null then
  ''url: ${repository.url}''
else
  assert repository.packages != null;
  let
    inherit (repository) name packages;
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
      packages;
    # Create linkFarm for no-index repository
    no-index-repository = pkgs.stdenv.mkDerivation
      {
        name = "no-index-repository-${name}";
        # TODO: use cabal-install from config
        buildInputs = [ pkgs.cabal-install ];
        dontUnpack = true;
        buildPhase = ''
          export CABAL_CONFIG=${pkgs.writeText "cabal-config" ''
            repository ${name}
              url: file+noindex://$out
          ''}
          mkdir -p $out
          cd $out

          ${lib.concatMapStringsSep "\n" (p: "ln -s ${p.path} ${p.name}") compressedPackages}
            
          cabal update
        '';
      };
  in
  ''url: file+noindex://${no-index-repository}''
