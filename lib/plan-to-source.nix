{ plan, pkgs }:
let
  inherit (plan) pkg-name pkg-version pkg-src-sha256 pkg-src;
in
if pkg-src.type == "repo-tar" then
  let
    src-tar-gz = (builtins.fetchurl {
      url = "${pkg-src.repo.uri}package/${pkg-name}-${pkg-version}/${pkg-name}-${pkg-version}.tar.gz";
      sha256 = pkg-src-sha256;
    });
    # FIXME: the fetched metadata is the latest and there's no guarantee it matches the hash
    metadata = (builtins.fetchurl {
      url =
        "${pkg-src.repo.uri}package/${pkg-name}-${pkg-version}/${pkg-name}.cabal";
      sha256 = plan.pkg-cabal-sha256;
    });
  in
  pkgs.stdenv.mkDerivation {
    name = pkg-name;
    src = src-tar-gz;
    installPhase = ''
      mkdir -p $out
      cd $out
            
      tar -xzf $src --strip-components=1
      ${if pkg-src.type == "source-repo" && pkg-src.source-repo ? "subdir" then
        "tar -xzf $src --strip-components=1"
        else "tar -xzf $src --strip-components=1"
      }

            
      ${if pkg-src.type == "repo-tar" then "cp ${metadata} ${pkg-name}.cabal" else ""}
    '';
    dontBuild = true;
  }
else if pkg-src.type == "source-repo" then
  assert pkg-src.source-repo ? "tag";
  let
    src =
      builtins.fetchGit
        {
          url = pkg-src.source-repo.location;
          rev = pkg-src.source-repo.tag;
        };
  in
  if pkg-src.source-repo ? "subdir" then "${src}/${pkg-src.source-repo.subdir}" else src
else
  assert pkg-src.type == "local";
  /. + pkg-src.path
