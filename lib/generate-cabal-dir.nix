{ pkgs, cabal-config, sha256 }:
pkgs.stdenv.mkDerivation {
  name = "example";
  buildInputs = [ pkgs.cabal-install pkgs.cacert ];
  buildCommand = ''
    export CABAL_CONFIG=${cabal-config}

    export CABAL_DIR="$(mktemp -d)"
    trap 'rm -rf -- "$CABAL_DIR"' EXIT

    ${pkgs.cabal-install}/bin/cabal update

    cp -r "$CABAL_DIR" $out
  '';

  outputHash = "sha256-${sha256}";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
}
