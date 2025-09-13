{ pkgs, secure-remote-repositories, generate-secure-repo-index-cache }:

let
  inherit (pkgs) lib;
  unzip-tar-gz-to-tar = { name, src }: pkgs.stdenv.mkDerivation {
    inherit name;
    inherit src;
    buildCommand = ''
      gunzip -c $src > $out
    '';
  };
  generate-package-dir = repo: pkgs.stdenv.mkDerivation {
    name = "${repo.name}-package";
    buildCommand = ''
      mkdir -p $out
      ${let
        index-tar = unzip-tar-gz-to-tar {
          name = "${repo.name}-01-index.tar";
          src = repo.index;
        };
      in ''
        ln -s ${index-tar} $out/01-index.tar
        ln -s ${repo.root} $out/root.json
        ls -al $out
        ${generate-secure-repo-index-cache} ${repo.name} $out
      ''}
    '';
  };
in
pkgs.stdenv.mkDerivation {
  name = "cabal-dir";
  buildInputs = [ pkgs.cabal-install pkgs.cacert ];
  buildCommand = ''
    mkdir -p $out/packages
    cd $out/packages

    ${lib.concatMapStringsSep "\n" (repo: "ln -s ${generate-package-dir repo} ${repo.name}") secure-remote-repositories}
  '';
}
