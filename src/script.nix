{
  cwd,
  lib,
  inputsFlakeFile,
  outputsExpr,
}: let
  inherit (builtins)
    any
    attrNames
    attrValues
    concatStringsSep
    filter
    foldl'
    head
    isAttrs
    isString
    mapAttrs
    split
    toJSON
    ;
  inherit (lib)
    filterAttrs
    flip
    hasInfix
    hasPrefix
    hasSuffix
    mapAttrsToList
    optionalString
    removePrefix
    ;

  concatAttrs = foldl' (a: b: a // b) { };

  flattenAttrs = sep: let
    recur = acc: path: attrs:
      foldl' (
        acc: name: let
          path' = path ++ [ name ];
          value = attrs.${name};
        in
          if isAttrs value && value.type or null != "derivation" && value.recurseForDerivations or null != false
          then recur acc path' (removeAttrs value [ "recurseForDerivations" ])
          else acc // { ${concatStringsSep sep path'} = value; }
      )
      acc (attrNames attrs);
  in
    attrs: recur { } [ ] attrs;

  # It is not possible to use `builtins.getFlake` as that would lead to fetching the very inputs we want to override.
  overriddenInputs =
    mapAttrs (name: input:
      if !input ? url
      then throw "The input '${name}' in the inputs flake should contain a 'url' attribute."
      else let
        url = toString input.url;
        prefix = head ((filter (flip hasPrefix url) [ "git+file://" "path:" ]) ++ [ "" ]);
        path = removePrefix prefix url;
        absPath =
          if hasInfix ":" path
          then throw "The url '${toString url}' does not have type 'git+file://' or 'path:' or is valid path."
          else if !(hasPrefix "/" path)
          then cwd + "/${path}"
          else path;
      in rec {
        inherit prefix;
        path = absPath;
        url = "${prefix}${toString path}";
      })
    (import (inputsFlakeFile + optionalString (!(hasSuffix ".nix" inputsFlakeFile)) "/flake.nix")).inputs
    or (throw "The inputs flake does not contain the top-level attribute 'inputs'.");

  overriddenInputInputs = mapAttrs (_: { path, ... }:
    (import (path + "/flake.nix")).inputs or { })
  overriddenInputs;

  followsOverriden = input:
    any (input: let
      follow = head (filter isString (split "/" input.follows));
    in
      overriddenInputs ? ${follow}) (attrValues input.inputs or { });

  inputsWithOverriddenFollows =
    concatAttrs (map (inputs: filterAttrs (name: input: followsOverriden input) inputs)
      (attrValues overriddenInputInputs));

  inputsWithPrefixedFollows = concatAttrs (mapAttrsToList (name: inputs:
    mapAttrs (
      _: { inputs, ... }:
        mapAttrs (_: input:
          if input ? follows
          then input // { follows = "${name}/${input.follows}"; }
          else input)
        inputs
    )
    (filterAttrs (name: input:
      (overriddenInputInputs ? ${name})
      && input ? url
      && any (input: input ? follows) (attrValues input.inputs or { }))
    inputs))
  overriddenInputInputs);

  inputs =
    inputsWithOverriddenFollows
    // mapAttrs (name: inputs: {
      inherit (overriddenInputs.${name}) url;
      inputs = filterAttrs (_: x: x != null) (
        mapAttrs (
          name: input:
            if overriddenInputInputs ? ${name} || followsOverriden input
            then { follows = name; }
            else null
        )
        inputs
        // inputsWithPrefixedFollows.${name} or { }
      );
    })
    overriddenInputInputs;
in let
  attrs = concatStringsSep "\n" (
    mapAttrsToList (name: input: let
      attrs = concatStringsSep "" (mapAttrsToList (
        name: value: "      ${name} = ${toJSON value};\n"
      ) (flattenAttrs "." input));
    in "    ${name} = {\n${attrs}    };\n")
    inputs
  );
in "{\n  inputs = {\n${attrs}  };\n\n  outputs = ${outputsExpr};\n}\n"
