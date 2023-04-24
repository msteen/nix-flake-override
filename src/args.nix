{
  cwd,
  nixpkgs,
}: let
  inputsFlakeFile = let
    value = builtins.getEnv "INPUTS_FLAKE_FILE";
  in
    if value == ""
    then throw "The environment variable 'INPUTS_FLAKE_FILE' is not set."
    else value;

  outputsExpr = let
    value = builtins.getEnv "OUTPUTS_EXPR";
  in
    if value == ""
    then throw "The environment variable 'OUTPUTS_EXPR' is not set."
    else value;
in {
  lib = import (nixpkgs + "/lib");
  inherit cwd inputsFlakeFile outputsExpr;
}
