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
    # llm-agents packages available via overlay if needed individually
    # e.g., pkgs.llm-agents.claude-code
  ];

  shellHook = ''
    nix-init() {
      command nix-init --config ${nixInitConfig} "$@"
    }
    export -f nix-init
  '';
}
