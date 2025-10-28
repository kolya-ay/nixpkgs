{
  description = "A Nix flake for packaging Goose and Gemini desktop applications.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-ai-tools,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            nix-ai-tools = nix-ai-tools.packages.${system};
          })
        ];
      };

      # Import the package definitions
      goose-desktop = pkgs.callPackage ./goose-desktop.nix {};
      gemini-desktop = pkgs.callPackage ./gemini-desktop.nix {};
      splitrail = pkgs.callPackage ./splitrail.nix {};

      # nix-init configuration
      nixInitConfig = pkgs.writeTextFile {
        name = "nix-init-config.toml";
        text = ''
          # nix-init configuration
          # See: https://github.com/nix-community/nix-init
          nixpkgs = 'builtins.getFlake "nixpkgs"'
        '';
      };
    in {
      # Expose the packages
      packages = {
        inherit goose-desktop gemini-desktop splitrail;
        default = goose-desktop;
      };

      # Expose as runnable apps
      apps = {
        goose = flake-utils.lib.mkApp {
          drv = goose-desktop;
        };
        gemini = flake-utils.lib.mkApp {
          drv = gemini-desktop;
        };
        default = self.apps.${system}.goose;
      };

      # Development shell for packaging
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nix-init
          cargo
          rustc
          nodejs
          npm
          electron
          pkgs.nix-ai-tools
        ];

        shellHook = ''
          mkdir -p "$HOME/.config/nix-init"
          ln -sf ${nixInitConfig} "$HOME/.config/nix-init/config.toml"
        '';
      };
    });
}
