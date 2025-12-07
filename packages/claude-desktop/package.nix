{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  p7zip,
  electron,
  nodejs,
  asar,
  icoutils,
  llm-agents,
}:

let
  pname = "claude-desktop";
  version = "1.0.1217";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://downloads.claude.ai/releases/win32/x64/${version}/Claude-0cb4a3120aa28421aeb48e8c54f5adf8414ab411.exe";
      hash = "sha256-baSOogkwk0wcG9UmZt4MFFj+ovtwidPQtHmsUnsUCIA=";
    };
    aarch64-linux = fetchurl {
      url = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe";
      hash = "sha256-fWBG4DMNUtW5C4wUJ8GMqgYJku03YlAn0YUT+Yf1fO4=";
    };
  };

  src =
    srcs.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
stdenv.mkDerivation rec {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    p7zip
    nodejs
    asar
    icoutils
  ];

  buildInputs = [
    electron
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "claude-desktop";
      desktopName = "Claude";
      comment = "Claude AI Desktop Application";
      exec = "claude-desktop %u";
      icon = "claude-desktop";
      categories = [
        "Office"
        "Utility"
        "Chat"
      ];
      mimeTypes = [ "x-scheme-handler/claude" ];
      startupNotify = true;
      startupWMClass = "Claude";
    })
  ];

  unpackPhase = ''
    runHook preUnpack

    # Extract the Windows installer
    echo "Extracting Windows installer..."
    7z x -y "$src" -o./extract >/dev/null

    # Find and extract the NuGet package
    cd extract
    local nupkg=$(find . -maxdepth 1 -name "AnthropicClaude-*.nupkg" | head -1)
    if [ -z "$nupkg" ]; then
      echo "Error: NuGet package not found"
      ls -la
      exit 1
    fi

    echo "Extracting NuGet package: $nupkg"
    7z x -y "$nupkg" >/dev/null
    cd ..

    # Prepare app directory
    mkdir -p ./app
    cp extract/lib/net45/resources/app.asar ./app/
    cp -r extract/lib/net45/resources/app.asar.unpacked ./app/ 2>/dev/null || true

    # Extract app.asar for modification
    cd ./app
    ${asar}/bin/asar extract app.asar app.asar.contents
    cd ..

    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild

    cd ./app

    # Copy i18n files into app.asar contents
    echo "Copying i18n files..."
    mkdir -p app.asar.contents/resources/i18n
    if ls ../extract/lib/net45/resources/*.json 1> /dev/null 2>&1; then
      cp ../extract/lib/net45/resources/*.json app.asar.contents/resources/i18n/
    fi

    # Create Linux-compatible native module using our Electron-integrated stub
    echo "Replacing claude-native module with Electron-integrated stub..."
    mkdir -p app.asar.contents/node_modules/claude-native
    cp ${./claude-stub.js} app.asar.contents/node_modules/claude-native/index.js

    # Fix title bar detection issue
    echo "Applying title bar fix..."
    local js_file=$(find app.asar.contents -name "MainWindowPage-*.js" 2>/dev/null | head -1)
    if [ -n "$js_file" ]; then
      sed -i -E 's/if\(!([a-zA-Z]+)[[:space:]]*&&[[:space:]]*([a-zA-Z]+)\)/if(\1 \&\& \2)/g' "$js_file"
      echo "Title bar fix applied to: $js_file"
    fi

    # Repack app.asar
    echo "Repacking app.asar..."
    ${asar}/bin/asar pack app.asar.contents app.asar
    rm -rf app.asar.contents

    cd ..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install application files
    mkdir -p $out/lib/claude-desktop
    cp -r ./app/* $out/lib/claude-desktop/

    # Copy locale files
    mkdir -p $out/lib/claude-desktop/locales
    cp ./extract/lib/net45/resources/*.json $out/lib/claude-desktop/locales/ 2>/dev/null || true

    # Create wrapper script
    makeWrapper ${electron}/bin/electron $out/bin/claude-desktop \
      --add-flags "$out/lib/claude-desktop/app.asar" \
      --set DISABLE_AUTOUPDATER 1 \
      --set NODE_ENV production \
      --prefix PATH : ${
        lib.makeBinPath [
          llm-agents.claude-code
          nodejs
        ]
      }

    # Extract and install icon using icoutils
    if [ -f ./extract/lib/net45/resources/TrayIconTemplate.png ]; then
      echo "Installing icon from TrayIconTemplate.png..."
      install -Dm644 ./extract/lib/net45/resources/TrayIconTemplate.png \
        $out/share/icons/hicolor/256x256/apps/claude-desktop.png
    elif [ -f ../extract/setupIcon.ico ]; then
      echo "Extracting and converting icons from setupIcon.ico..."
      mkdir -p ./icons
      wrestool -x -t 14 ../extract/setupIcon.ico > ./icons/icon.ico 2>/dev/null || \
        cp ../extract/setupIcon.ico ./icons/icon.ico

      icotool -x ./icons/icon.ico -o ./icons/ 2>/dev/null || true

      # Install extracted icons (skip low quality small icons)
      for icon in ./icons/*.png; do
        if [ -f "$icon" ]; then
          size=$(identify -format "%wx%h" "$icon" 2>/dev/null || echo "unknown")
          if [ "$size" != "16x16" ] && [ "$size" != "32x32" ] && [ "$size" != "unknown" ]; then
            mkdir -p "$out/share/icons/hicolor/$size/apps"
            cp "$icon" "$out/share/icons/hicolor/$size/apps/claude-desktop.png"
          fi
        fi
      done
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude AI Desktop Application";
    homepage = "https://claude.ai";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "claude-desktop";
  };
}
