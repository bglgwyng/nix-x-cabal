{ pkgs, plan-json }:
let
  install-plan = plan-json.install-plan;
  configureds = builtins.filter (x: x.type == "configured" && x.pkg-src.type == "repo-tar") install-plan;
in
builtins.listToAttrs (builtins.map
  ({ pkg-name, pkg-version, pkg-src-sha256, pkg-cabal-sha256, ... }: {
    name = pkg-name;
    value = {
      source =
        let
          src-tar-gz = (builtins.fetchurl {
            url =
              "https://hackage.haskell.org/package/${pkg-name}-${pkg-version}/${pkg-name}-${pkg-version}.tar.gz";
            sha256 = pkg-src-sha256;
          });
          # FIXME: the fetched metadata is the latest and there's no guarantee it matches the hash
          metadata = (builtins.fetchurl {
            url =
              "https://hackage.haskell.org/package/${pkg-name}-${pkg-version}/${pkg-name}.cabal";
            sha256 = pkg-cabal-sha256;
          });
        in
        pkgs.stdenv.mkDerivation {
          name = pkg-name;
          src = src-tar-gz;
          installPhase = ''
            mkdir -p $out
            cd $out
            tar -xvf $src --strip-components=1
            cp ${metadata} ${pkg-name}.cabal
          '';
          dontBuild = true;

        };
    };
  })
  configureds
)
