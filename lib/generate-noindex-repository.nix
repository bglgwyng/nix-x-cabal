# Repository utility functions
{ lib, pkgs, generate-noindex-cache }:
repository:
assert repository.packages != null;
let
  inherit (repository) name packages;
  # Compress each package as .tar.gz
  compressed-packages = map
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
in
pkgs.stdenv.mkDerivation {
  name = "no-index-repository-${name}";
  # TODO: use cabal-install from config
  buildInputs = [ pkgs.cabal-install ];
  dontUnpack = true;
  buildPhase = ''
    mkdir -p $out
    cd $out

    ${lib.concatMapStringsSep "\n" (p: "ln -s ${p.path} ${p.name}") compressed-packages}

    ${generate-noindex-cache} $out                
  '';
}
