{
  description = "A Nix flake for packaging Goose and Gemini desktop applications.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      nixpkgs.overlays = [
        (final: prev: {
          nix-ai-tools = inputs.nix-ai-tools.packages.${final.system};
        })
      ];
    };
}
