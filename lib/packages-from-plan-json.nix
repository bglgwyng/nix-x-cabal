{ pkgs, plan-json, haskellPackages ? pkgs.haskellPackages, get-local-package-deps }:
let
  inherit (pkgs) lib haskell;
  install-plan = plan-json.install-plan;
  configured-components = builtins.filter (pkg: pkg.type == "configured") install-plan;
  components-by-id = builtins.listToAttrs (map (plan: { name = plan.id; value = plan; }) configured-components);
  package-srcs = builtins.mapAttrs
    (name: components:
      let
        the-component = builtins.head components;
        all-equal = xs:
          let first = builtins.head xs;
          in builtins.all (x: x == first) (builtins.tail xs);
        inherit (the-component) pkg-src;
      in
      assert (
        if pkg-src.type == "repo-tar" then
          all-equal (map (plan: plan.pkg-src-sha256) components)
          && all-equal (map (plan: plan.pkg-cabal-sha256) components)
        else
          assert pkg-src.type == "local";
          all-equal (map (plan: pkg-src.path) components)
      );
      {
        src = pkgs.callPackage ./plan-to-source.nix {
          plan = the-component;
          inherit get-local-package-deps;
        };
        is-local = the-component.style == "local";
        components = components;
      }
    )
    (builtins.groupBy (plan: plan.pkg-name) configured-components);
  extract-depends = components:
    let self-component-ids = map (plan: plan.id) components;
    in
    # for example, constraints-extras:exe:readme depends on constraints-extras:lib. this filter removes it.
    builtins.filter (id: !builtins.elem id self-component-ids)
      (builtins.concatMap
        # TODO: check if ignoring `exe-depends` is ok
        (component:
          (component.depends or [ ])
          ++ (if component ? "components" then
            builtins.concatMap (component: (component.depends or [ ])) (builtins.attrValues component.components)
          else [ ]
          )
        )
        components);
  extract-build-targets = components:
    (builtins.concatMap
      (component:
        map
          (component-name: if component-name == "lib" then "lib:${component.pkg-name}" else component-name)
          (if component ? "component-name" then
            [ component.component-name ]
          else
            assert component ? "components";
            builtins.filter (name: name != "setup") (builtins.attrNames component.components))
      )
      components);
  override-haskell-packages-in-plan = name: package:
    let
      inherit (package) components src;
      the-component = builtins.head components;
      overrides = lib.pipe components
        [
          extract-depends
          (builtins.concatMap (id: if components-by-id ? "${id}" then [ components-by-id.${id}.pkg-name ] else [ ]))
          lib.unique
          (map (name: { name = name; value = overrided-packages.${name}; }))
          builtins.listToAttrs
        ];
    in
    lib.pipe
      ((haskellPackages.callCabal2nix name src overrides))
      [
        haskell.lib.dontCheck
        (haskell.lib.compose.setBuildTargets (extract-build-targets components))
      ];
  overrided-packages = builtins.mapAttrs override-haskell-packages-in-plan package-srcs;
  global-packages = lib.filterAttrs (name: _: !package-srcs.${name}.is-local) overrided-packages;
  local-packages = lib.filterAttrs (name: _: package-srcs.${name}.is-local) overrided-packages;
in
{ inherit global-packages local-packages; }
