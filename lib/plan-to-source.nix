{ pkgs, plan, get-local-package-deps, get-cabal-metadata }:
let
  inherit (pkgs) lib;
  inherit (plan) pkg-name pkg-version pkg-src-sha256 pkg-src;
in
if pkg-src.type == "repo-tar" then
  if pkg-src.repo.type == "secure-repo" then
    let
      src-tar-gz = (builtins.fetchurl {
        url = "${pkg-src.repo.uri}package/${pkg-name}-${pkg-version}/${pkg-name}-${pkg-version}.tar.gz";
        sha256 = pkg-src-sha256;
      });
      metadata =
        let metadata-from-index = get-cabal-metadata { remote-url = pkg-src.repo.uri; name = pkg-name; version = pkg-version; }; in
        assert (builtins.hashFile "sha256" metadata-from-index == plan.pkg-cabal-sha256);
        metadata-from-index;
      # we don't have a way to fetch the metadata from the index with the exact hash
      # builtins.fetchurl {
      #   url =
      #     "${pkg-src.repo.uri}package/${pkg-name}-${pkg-version}/${pkg-name}.cabal";
      #   sha256 = plan.pkg-cabal-sha256;
      # };
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
  else assert pkg-src.repo.type == "local-repo-no-index";
  pkgs.stdenv.mkDerivation {
    name = pkg-name;
    src = (pkg-src.repo.path + "/${pkg-name}-${pkg-version}.tar.gz");
    buildInputs = get-local-package-deps pkg-name pkg-version;
    installPhase = ''
      mkdir -p $out
      cd $out
            
      tar -xzf $src --strip-components=1
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
  
