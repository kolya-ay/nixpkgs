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
  pnpmDeps = pnpm_10.fetchDeps {
    inherit pname version src;
    sourceRoot = "${src.name}/frontend";
    fetcherVersion = 1;
    hash = "sha256-ifI92eaijbj18mycQcWQw+YG7mbQBCUbskaA8jOktsY=";
  };

  TAURI_FRONTEND_PATH = "frontend";
  pnpmRoot = "frontend";

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    cargo-tauri.hook
    nodejs
    pnpm_10.configHook
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "gemini-desktop";
      desktopName = "Gemini Desktop";
      comment = "Desktop UI for Gemini CLI/Qwen Code";
      exec = "gemini-desktop %U";
      icon = "gemini-desktop";
      categories = [ "Development" "X-LLM" ];
      terminal = false;
      startupNotify = true;
    })
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

  postInstall = ''
    install -Dm644 ${src}/crates/tauri-app/icons/32x32.png \
      $out/share/icons/hicolor/32x32/apps/gemini-desktop.png
    install -Dm644 ${src}/crates/tauri-app/icons/64x64.png \
      $out/share/icons/hicolor/64x64/apps/gemini-desktop.png
    install -Dm644 ${src}/crates/tauri-app/icons/128x128.png \
      $out/share/icons/hicolor/128x128/apps/gemini-desktop.png
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
