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
    url = mkOption {
      type = types.nullOr types.str;
      description = "Repository URL";
      default = null;
    };
    packages = mkOption {
      type = types.nullOr (types.listOf local-package);
      description = "Packages or paths for local no-index repository.";
      default = null;
    };
  };
})

