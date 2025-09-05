{ pkgs, plan-json }:
let
  install-plan = plan-json.install-plan;
  configureds = builtins.filter (pkg: pkg.type == "configured" && (pkg.pkg-src.type == "repo-tar" || pkg.pkg-src.type == "source-repo")) install-plan;
in
builtins.listToAttrs (builtins.map (plan: pkgs.callPackage ./plan-to-source.nix { inherit plan; }) configureds)
