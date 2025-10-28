{ pkgs }:
let
  nixInitConfig = pkgs.writeTextFile {
    name = "nix-init-config.toml";
    text = ''
      # nix-init configuration
      # See: https://github.com/nix-community/nix-init
      nixpkgs = 'builtins.getFlake "nixpkgs"'
    '';
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.nix-init
    pkgs.cargo
    pkgs.rustc
    pkgs.nodejs
    pkgs.electron
    # nix-ai-tools packages available via overlay if needed individually
    # e.g., pkgs.nix-ai-tools.claude-code
  ];

  shellHook = ''
    nix-init() {
      command nix-init --config ${nixInitConfig} "$@"
    }
    export -f nix-init
  '';
}
