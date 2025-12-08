{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "ai-sessions-mcp";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "yoavf";
    repo = "ai-sessions-mcp";
    rev = "v${version}";
    hash = "sha256-KLXW5Gyacu4v4E1eMvGPpUupaerjp74PxNpPblJM1gA=";
  };

  vendorHash = "sha256-/nbpUIa856/LaPT59VjLcMwGkTuywRiwjvyOpzNP/0I=";

  ldflags = [ "-s" "-w" ];

  meta = {
    description = "MCP server for searching and accessing your AI coding sessions from Claude Code,  Gemini CLI, opencode, and OpenAI Codex. Also an uploader for aisessions.dev";
    homepage = "https://github.com/yoavf/ai-sessions-mcp";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ai-sessions-mcp";
  };
}
