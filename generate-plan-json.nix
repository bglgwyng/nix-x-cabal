{ pkgs, haskellPackages ? pkgs.haskellPackages, project-dir }:
pkgs.writeShellScriptBin "plan-${pkgs.system}.json" ''
  MYTMP="$(mktemp -d)"
  trap 'rm -rf -- "$MYTMP"' EXIT

  ${haskellPackages.cabal-install}/bin/cabal build all \
    --project-dir=${project-dir} \
    --dry-run \
    --builddir=$MYTMP \
    --with-compiler=${haskellPackages.ghc}/bin/ghc

  mkdir -p plans

  mv $MYTMP/cache/plan.json plans/plan-${pkgs.system}.json
''
