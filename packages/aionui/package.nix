{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  electron,
  makeDesktopItem,
  copyDesktopItems,
  llm-agents,
  nodejs,
  python3,
}:

let
  pname = "aionui";
  version = "1.6.4";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/iOfficeAI/AionUi/releases/download/v${version}/AionUi-${version}-linux-x86_64.AppImage";
      hash = "sha256-DurCYWYZEoB64XXEG7DWjJ9cP8P8msVa5K5E1SwEwUs=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/iOfficeAI/AionUi/releases/download/v${version}/AionUi-${version}-linux-arm64.AppImage";
      hash = "sha256-WMj9o1RmZkLi4stx/rt7MwykITnCTJdMSdT2oBomf5M=";
    };
  };

  src =
    srcs.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageContents;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    nodejs
    python3
  ];

  buildInputs = [
    electron
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "aionui";
      desktopName = "AionUi";
      comment = "Transform your command-line AI agent into a modern AI Chat interface";
      exec = "aionui %U";
      icon = "aionui";
      categories = [
        "Development"
        "Utility"
        "Office"
      ];
      startupNotify = true;
      mimeTypes = [ "x-scheme-handler/aionui" ];
    })
  ];

  dontConfigure = true;

  # Rebuild native modules against Electron headers
  buildPhase = ''
    runHook preBuild

    export npm_config_nodedir=${electron.headers}
    export HOME=$TMPDIR

    cd resources/app.asar.unpacked
    npm rebuild --verbose better-sqlite3 bcrypt node-pty
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install application files
    mkdir -p $out/lib/aionui
    cp -r resources/* $out/lib/aionui/

    # Install icons from AppImage (handles various sizes including 1024)
    for size in 16 32 48 64 128 256 512 1024; do
      icon_path="usr/share/icons/hicolor/''${size}x''${size}/apps"
      if [ -d "$icon_path" ]; then
        for icon in "$icon_path"/*.png; do
          if [ -f "$icon" ]; then
            install -Dm644 "$icon" \
              "$out/share/icons/hicolor/''${size}x''${size}/apps/aionui.png"
          fi
        done
      fi
    done

    # Fallback: check root-level icon symlink (common in AppImages)
    if [ ! -f "$out/share/icons/hicolor/256x256/apps/aionui.png" ]; then
      if [ -f "AionUi.png" ]; then
        install -Dm644 "AionUi.png" \
          "$out/share/icons/hicolor/256x256/apps/aionui.png"
      fi
    fi

    # Create wrapper with AI CLI tools in PATH
    makeWrapper ${electron}/bin/electron $out/bin/aionui \
      --add-flags "$out/lib/aionui/app.asar" \
      --prefix PATH : "${
        lib.makeBinPath [
          llm-agents.gemini-cli
          llm-agents.claude-code
          llm-agents.qwen-code
        ]
      }" \
      --set ELECTRON_IS_DEV 0 \
      --set NODE_ENV production

    runHook postInstall
  '';

  meta = with lib; {
    description = "Transform your command-line AI agent into a modern AI Chat interface";
    homepage = "https://github.com/iOfficeAI/AionUi";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "aionui";
  };
}
