{ pkgs }:

with pkgs;

rustPlatform.buildRustPackage rec {
  pname = "splitrail";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "Piebald-AI";
    repo = "splitrail";
    rev = "v${version}";
    hash = "sha256-eihy3tOCdVDM514bRd/Z4xmof8v2D6gbOfRxYUUu5QY=";
  };

  cargoHash = "sha256-s/RY9YiSrIO3sFTbJbWHkvum8Kpbab5QjBlurk8w+0c=";

  # Requires nightly Rust for if_let_guard feature
  RUSTC_BOOTSTRAP = "1";

  meta = {
    description = "Token usage tracker and cost monitor for Gemini CLI/Claude Code/Codex";
    homepage = "https://github.com/Piebald-AI/splitrail";
    changelog = "https://github.com/Piebald-AI/splitrail/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "splitrail";
  };
}
