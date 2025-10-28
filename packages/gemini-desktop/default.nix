{ pkgs }:

with pkgs;

rustPlatform.buildRustPackage rec {
  pname = "gemini-desktop";
  version = "0.3.10";

  src = fetchFromGitHub {
    owner = "Piebald-AI";
    repo = "gemini-cli-desktop";
    rev = "v${version}";
    hash = "sha256-jfr5/pIVxmCnKTGbRFXaIxgbOxNXdcq1+N6K9QXE910=";
  };

  cargoHash = "sha256-k/PP5AJIJm4G9d/6V5MxNaNGEHbYJmt1o/Jh8/uAtKQ=";
  # Frontend dependencies
  pnpmDeps = pnpm_9.fetchDeps {
    inherit pname version src;
    sourceRoot = "${src.name}/frontend";
    fetcherVersion = 2;
    hash = "sha256-8vvWVoY8KZoRFzkcKFIF0MImtz0VVGu+NeNR8H9bYcs=";
    # Remove incomplete pnpm-workspace.yaml during deps fetch
    postPatch = ''
      rm -f pnpm-workspace.yaml
    '';
  };

  TAURI_FRONTEND_PATH = "frontend";
  pnpmRoot = "frontend";

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    cargo-tauri.hook
    nodejs
    pnpm_9.configHook
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    gtk4
    webkitgtk_4_1
  ];

  # Build only the tauri-app package from the workspace
  cargoBuildFlags = [
    "--package"
    "tauri-app"
  ];

  # Remove the incomplete pnpm-workspace.yaml for the main build too
  postPatch = ''
    rm -f frontend/pnpm-workspace.yaml
  '';

  postInstall = ''
    mkdir -p $out/share/icons
    cp ${src}/frontend/public/favicon-32x32.png $out/share/icons/gemini-desktop.png
  '';

  # The cargo-tauri hook handles the installation automatically
  meta = with lib; {
    homepage = "https://github.com/Piebald-AI/gemini-cli-desktop";
    description = "Desktop UI for Gemini CLI/Qwen Code";
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.mit;
    mainProgram = pname;
  };
}
