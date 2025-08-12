# nix-hs-plan

Get Haskell packages from 'plan.json' file.

```shell
nix run github:bglgwyng/nix-hs-plan#generate-plan-json
```
then you can get 'plans/plan-${system}.json' file.

In [haskell-flake](https://github.com/srid/haskell-flake) module
```nix
{
  packages = 
    (inputs.nix-hs-plan.packages-from-plan-json {
      inherit pkgs;
      plan-json = builtins.fromJSON (builtins.readFile ./plans/plan-${system}.json);
    });
}
```

For more information, see [this example](https://github.com/bglgwyng/nix-hs-plan-example).