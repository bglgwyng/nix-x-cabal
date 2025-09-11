# Local package type definition
{ lib }:
let
  inherit (lib) mkOption types;
in
types.submodule {
  options = {
    name = mkOption { type = types.str; };
    version = mkOption { type = types.str; };
    src = mkOption { type = types.path; };
  };
}