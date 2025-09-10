{ pkgs, plan-json, haskellPackages ? pkgs.haskellPackages }:
let
  inherit (pkgs) lib haskell;
  install-plan = plan-json.install-plan;
  components =
    builtins.filter
      (pkg: pkg.type == "configured" && (pkg.pkg-src.type == "repo-tar" || pkg.pkg-src.type == "source-repo"))
      install-plan;
  components-by-id = builtins.listToAttrs (builtins.map (plan: { name = plan.id; value = plan; }) components);
  packages =
    builtins.mapAttrs
      (name: components:
        let
          the-component = builtins.head components;
          all-equal = xs:
            let first = builtins.head xs;
            in builtins.all (x: x == first) (builtins.tail xs);
        in
        assert all-equal (builtins.map (plan: plan.pkg-src-sha256) components);
        assert all-equal (builtins.map (plan: plan.pkg-cabal-sha256) components);
        {
          src = pkgs.callPackage ./plan-to-source.nix { plan = the-component; };
          components = components;
        })
      (builtins.groupBy (plan: plan.pkg-name) components);
  extract-depends = components:
    let self-component-ids = builtins.map (plan: plan.id) components;
    in
    # for example, constraints-extras:exe:readme depends on constraints-extras:lib. this filter removes it.
    builtins.filter (id: !builtins.elem id self-component-ids)
      (builtins.concatMap
        # TODO: check if ignoring `exe-depends` is ok
        (component:
          (component.depends or [ ])
          ++ (if component ? "components" then
            builtins.concatMap (component: (component.depends or [ ])) (builtins.attrValues component.components)
          else [ ])
        )
        components);
  extract-build-targets = components:
    (builtins.concatMap
      (component:
        builtins.map
          (component-name: if component-name == "lib" then "lib:${component.pkg-name}" else component-name)
          (if component ? "component-name" then
            [ component.component-name ]
          else
            assert component ? "components";
            builtins.attrNames component.components)
      )
      components);
  override-haskell-packages-in-plan = name: package:
    let
      inherit (package) components src;
      the-component = builtins.head components;
      overrides =
        lib.pipe components
          [
            extract-depends
            (builtins.concatMap (id: if components-by-id ? "${id}" then [ components-by-id.${id}.pkg-name ] else [ ]))
            lib.unique
            (builtins.map (name: { name = name; value = overrided-packages.${name}; }))
            builtins.listToAttrs
          ];
    in
    lib.pipe
      (haskellPackages.callCabal2nix name src { })
      [
        (drv: drv.override overrides)
        haskell.lib.dontCheck
        (haskell.lib.compose.setBuildTargets (extract-build-targets components))
      ];
  overrided-packages =
    builtins.mapAttrs
      override-haskell-packages-in-plan
      packages;
in
overrided-packages
