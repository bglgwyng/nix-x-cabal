# Repository utility functions
{ lib, pkgs, generate-noindex-cache }:
repository:
assert repository.packages != null;
let
  inherit (repository) name packages;
  zip-to-tar-gz = src: pkgs.runCommand "idk.tar.gz" { } ''
    name=$(sed -n 's/^name: *//p' ${src}/*.cabal | head -1)
    version=$(sed -n 's/^version: *//p' ${src}/*.cabal | head -1)

    mkdir $name-$version
    cp -r ${src}/* $name-$version/
    tar -czf $out $name-$version
  '';
in
pkgs.stdenv.mkDerivation {
  name = "no-index-repository-${name}";
  # TODO: use cabal-install from config
  buildInputs = [ pkgs.cabal-install ];
  dontUnpack = true;
  buildPhase = ''
    mkdir -p $out
    cd $out

    ${lib.concatMapStringsSep "\n" (src: ''
      name=$(sed -n 's/^name: *//p' ${src}/*.cabal | head -1)
      version=$(sed -n 's/^version: *//p' ${src}/*.cabal | head -1)

      ln -s ${zip-to-tar-gz src} $name-$version.tar.gz
      '') packages}

    ${generate-noindex-cache} $out                
  '';
}
