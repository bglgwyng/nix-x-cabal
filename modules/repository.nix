{ lib, pkgs }:
let
  inherit (lib) mkOption types;
in
types.submodule ({ config, ... }: {
  options = {
    # For remote repository
    url = mkOption {
      type = types.nullOr types.str;
      description = "Repository URL";
      default = null;
    };
    type = mkOption {
      type = types.enum [ "remote-secure" "local-no-index" ];
      description = "Repository type";
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
  config = {
    type =
      lib.throwIf (config.url == null && config.packages == null) "Repository must have either url or packages specified"
        (lib.throwIf (config.url != null && config.packages != null) "Repository cannot have both url and packages specified"
          (if config.url != null then
            "remote-secure"
          else
            "local-no-index"));
  };
})

