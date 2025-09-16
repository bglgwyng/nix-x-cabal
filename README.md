# nix-x-cabal

Blessed shipping between Nix and Cabal

nix-x-cabal delegates all package fetching to Nix while using Cabal in pure mode with pre-fetched packages. 

## How It Works

1. **Repository Setup**
   - Creates deterministic Cabal repositories (remote-secure and local-noindex) from Nix

2. **Build Process**
   - Generates `plan.json` offline using configured repositories
   - Fetches all dependencies via Nix

For more details, check out [examples](https://github.com/bglgwyng/nix-x-cabal-example)


## Important Note
`source-repository-package` cannot be used in `cabal.project`.
Instead, configure a local noindex repository.