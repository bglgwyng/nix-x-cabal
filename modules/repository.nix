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
    # For remote repository
    url = mkOption {
      type = types.nullOr types.str;
      description = "Repository URL";
      default = null;
    };
    index = mkOption {
      type = types.nullOr types.path;
      description = "Repository 01-index.tar.gz";
      default = null;
    };
    root = mkOption {
      type = types.nullOr types.path;
      description = "Repository root.json";
      default = null;
    };
    # For local no-index repository
    packages = mkOption {
      type = types.nullOr (types.listOf types.path);
      description = "Packages or paths for local no-index repository.";
      default = null;
    };
  };
})

