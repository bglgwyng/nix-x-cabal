{
  description = "Haskell packages from plan.json";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        {
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.

          apps.generate-plan-json = {
            type = "app";
            program = import ./generate-plan-json.nix { inherit pkgs; };
          };
        };
      flake = {
        generate-plan-json = import ./generate-plan-json.nix;
        package-srcs-from-plan-json = import ./packages-from-plan-json.nix;
        packages-from-plan-json =
          { pkgs, plan-json, haskellPackages ? pkgs.haskellPackages }:
          let
            install-plan = plan-json.install-plan;
            configureds =
              builtins.filter
                (
                  pkg:
                  let
                    x = pkg.type == "configured"
                      && (pkg.pkg-src.type == "repo-tar" || pkg.pkg-src.type == "source-repo")
                      # TODO: exclusive?
                      # "lib(:.*)?"
                      && (!(pkg ? "component-name") || (builtins.match "^lib$" pkg.component-name != null))
                      && (!(pkgs ? "components") || pkg.components ? "lib");
                  in
                  # builtins.trace
                    #   (builtins.toJSON [
                    #     pkg.pkg-name
                    #     (pkgs ? "component-name")
                    #     # ) || builtins.trace pkg (builtins.match "lib(:.*)?" pkg.component-name != null))
                    #     # (!(pkgs ? "components") || pkgs.components ? "lib")
                    #   ])
                  x
                )
                install-plan;
            srcs = builtins.listToAttrs (builtins.map (plan: pkgs.callPackage ./plan-to-source.nix { inherit plan; }) configureds);
            packages-by-id =
              # builtins.trace (builtins.toJSON (builtins.map (plan: plan.pkg-name) configureds))
              (builtins.listToAttrs
                (builtins.map
                  (plan:
                    let src = pkgs.callPackage ./plan-to-source.nix { inherit plan; }; in
                    {
                      name = plan.id;
                      value = { inherit src plan; };
                    })
                  configureds));
            extract-depens = plan:
              (if plan ? "depends" then plan.depends else [ ])
              ++ (if plan ? "components" then plan.components.lib.depends else [ ]);
            override-haskell-packages-in-plan = (name: value:
              let inherit (value) plan src;
                xs = builtins.listToAttrs (
                  builtins.map
                    (id: { name = packages-by-id.${id}.plan.pkg-name; value = overided-packages-by-id.${id}; })
                    (builtins.filter
                      (id: packages-by-id ? "${id}")
                      (extract-depens plan)));
              in
              # (haskellPackages.callCabal2nix plan.pkg-name src { }).override { }
                # builtins.trace name (builtins.trace (extract-depens plan) (builtins.trace xs 
                # (
              pkgs.haskell.lib.dontHaddock
                (pkgs.haskell.lib.dontCheck
                  ((haskellPackages.callCabal2nix plan.pkg-name src { }).override (
                    xs
                  )))
              # )))
            );
            overided-packages-by-id =
              builtins.mapAttrs
                override-haskell-packages-in-plan
                packages-by-id;
          in
          overided-packages-by-id;
        # builtins.mapAttrs (name: src: (haskellPackages.callCabal2nix name src.source { }).override { }) srcs;
      };
    };
}
