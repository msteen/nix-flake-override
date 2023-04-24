# `nix-flake-override`
This script automates generating a flake based on the inputs you want override. It produces a flat list of inputs, working around the following current issues with overriding flake inputs:

1. It is currently not possible to override the inputs of inputs within a flake. Meaning that `foo.inputs.bar.inputs.baz.url = ...` is not allowed.

2. It is also not possible to change and input and have old references to it within the input still work. Meaning that `foo.inputs.bar.url = ...` and within `foo` there is also something called `baz` that follows `bar` or some input of it like `bar/nixpkgs`, it will fail with the error that is refers to a non-existent input.

3. Relative paths are not allowed.

## Installation
Just like most other packages, but here are a few examples how to.
### Nix
- With `nix-env`:
  ```bash
  nix-env -if https://github.com/msteen/nix-flake-override/tarball/main
  ```

- With `nix profile`:
  ```bash
  nix profile install github:msteen/nix-flake-override
  ```

### NixOS
- Without flakes:
  ```nix
  let
    nix-flake-override =
      (import (builtins.fetchTarball {
        url = "https://github.com/msteen/nix-flake-override/tarball/main";
        sha256 = "0000000000000000000000000000000000000000000000000000";
      }) { })
      .outPath;
  in {
    environment.systemPackages = [ nix-flake-override ];
  }
  ```
  Note: You will have to update the `sha256` attribute yourself with the correct hash as provided by the error message, or fetched through some prefetch tool.

- With flakes:
  ```nix
  {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
      nix-flake-override.url = "github:msteen/nix-flake-override";
      nix-flake-override.inputs.nixpkgs.follows = "nixpkgs";
    };
  
    outputs = {
      nixpkgs,
      nix-flake-override,
      ...
    }: {
      nixosConfigurations = {
        example = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            { environment.systemPackages = [ nix-flake-override.packages.${system}.default ]; }
            # ...
          ];
        };
      };
    };
  }
  ```

## Usage
It takes a `.nix` file, or a directory that should contain a `flake.nix` file, containing a top-level `inputs` attribute conform the rules of flakes in general as the first argument. And as the second argument it takes a string representing the outputs expression, e.g. `inputs: inputs.foo`. The second argument is used when generating the new flake file.

The inputs of the flake file are only allowed to have `url` attributes containing:
- relative or absolute paths
- `path:` prefixed relative or absolute paths
- `git+file://` prefixed relative or absolute paths

Support for more input types can be added in the future.

An example of such a flake:
```nix
{
  inputs = {
    nixcfg.url = "git+file://../nixcfg.lib";
    nixcfg-public.url = "git+file://../nixcfg-public-flake";
    nixcfg-shared.url = "git+file://../nixcfg-shared-flake";
    nixcfg-matthijs.url = "git+file://../nixcfg-matthijs-flake";
  };

  outputs = _: { };
}
```

Note: The tool doesn't care about the `outputs` attribute, but it is nice for the file to be a valid flake, given we expect the inputs the conform the rules of flakes.

Due to only supporting local inputs at the moment, the flake we want to override has to be local as well. In the above example this would be the `nixcfg-matthijs` flake. For that reason we will have it represent our `outputs` expression.

An example output for `nix-flake-override inputs-flake.nix 'inputs: inputs.nixcfg-matthijs'`:
```nix
{
  inputs = {
    nixcfg = {
      inputs.nixpkgs.follows = "nixcfg-public/nixos-stable";
      url = "git+file:///home/matthijs/Code/nixcfg.lib";
    };

    nixcfg-matthijs = {
      inputs.nixcfg-shared.follows = "nixcfg-shared";
      inputs.nixcfg.follows = "nixcfg";
      url = "git+file:///home/matthijs/Code/nixcfg-matthijs-flake";
    };

    nixcfg-public = {
      inputs.nixcfg.follows = "nixcfg";
      url = "git+file:///home/matthijs/Code/nixcfg-public-flake";
    };

    nixcfg-shared = {
      inputs.nixcfg-public.follows = "nixcfg-public";
      inputs.nixcfg.follows = "nixcfg";
      inputs.phps.follows = "phps";
      url = "git+file:///home/matthijs/Code/nixcfg-shared-flake";
    };

    phps = {
      inputs.nixpkgs.follows = "nixcfg-public/nixos-stable";
      inputs.utils.follows = "nixcfg-public/extra-container/flake-utils";
      url = "github:fossar/nix-phps";
    };
  };

  outputs = inputs: inputs.nixcfg-matthijs;
}
```

## Implementation
The implementation is likely to not cover all use cases yet. For now the implemented logic is roughly as follows:

1. Normalize all the `url` attributes on the overridden inputs to absolute paths.

2. Of all overridden inputs, take their inputs if they follow one of the overriden inputs. An example of this is `phps`.

3. Of the inputs of the overriden inputs, filter out those that are, e.g. `nixcfg-shared.url = "...";`, or follow, .e.g. `nixcfg.follows = "nixcfg-shared/nixcfg";`, one of the overridden inputs.

4. Prefix existing `follows` in the overriden inputs inputs with the name of the overridden input if they are a defining input, i.e. have an `url` attribute. For example:
    ```nix
    {
        inputs.nixcfg = {
          url = "github:msteen/nixcfg.lib";
          inputs.nixpkgs.follows = "nixos-stable";
        };
    }
    ```
