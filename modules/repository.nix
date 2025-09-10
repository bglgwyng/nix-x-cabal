{ lib }:
let
  inherit (lib) mkOption types;
in
types.submodule {
  options = {
    url = mkOption {
      type = types.str;
      description = "Repository URL";
    };
  };
}
