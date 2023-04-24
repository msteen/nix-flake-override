{
  pkgs,
  writeShellScriptBin,
}:
writeShellScriptBin "nix-flake-override" ''
  help_ret=1
  if (( $# != 2 )) || { [[ $1 =~ ^(-h|--help)$ ]] && help_ret=0; }; then
    cat <<'EOF' >&2
  Use the inputs defined in the given flake to produce another flake that overrides all usage of those inputs.
  This is done by duplicating inputs and rewriting follows where necessary.

  Usage:
    nix-flake-override <flake> <outputs-expr>
    nix-flake-override -h | --help

  Options:
    -h, --help  Show help message.

  Examples:
    nix-flake-override inputs-flake.nix 'inputs: inputs.overridden'
    nix-flake-override ./path/to/flake/dir '_: { }'
  EOF
    exit $help_ret
  fi
  src=${./src}
  INPUTS_FLAKE_FILE=$(realpath "$1") OUTPUTS_EXPR=$2 nix eval --impure --raw \
    --expr "import $src/script.nix (import $src/args.nix { cwd = ./.; nixpkgs = ${toString pkgs.path}; })"
''
