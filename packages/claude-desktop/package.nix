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
  ast-grep,
}:

let
  # Version update process:
  # 1. Check AUR PKGBUILD for latest version and x64 commit hash:
  #    https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=claude-desktop-bin
  #    Look for: pkgver and source_x86_64 URL's Claude-{hash}.exe
  # 2. Update version and x64CommitHash below, then run update script:
  #    cd packages/claude-desktop && ./update.py
  # 3. Verify: NIXPKGS_ALLOW_UNFREE=1 nix build .#claude-desktop --impure
  pname = "claude-desktop";
  version = "1.0.1768";
  x64CommitHash = "67d01376d0e9d08b328455f6db9e63b0d603506a";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://downloads.claude.ai/releases/win32/x64/${version}/Claude-${x64CommitHash}.exe";
      hash = "sha256-x76Qav38ya3ObpWIq3dDowo79LgvVquMfaZeH8M1LUk=";
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
    ast-grep
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

    # Inject global helper functions at the top of index.js
    echo "Injecting global helpers..."
    local index_js="app.asar.contents/.vite/build/index.js"
    if [ -f "$index_js" ]; then
      cat ${./globals-inject.js} "$index_js" > /tmp/new-index.js
      mv /tmp/new-index.js "$index_js"

      # Verify injection
      if grep -q "getNixClaudePath" "$index_js"; then
        echo "✓ Global helpers injected"
      else
        echo "✗ Failed to inject global helpers"
        exit 1
      fi
    fi

    # Apply all ast-grep patches (index.js + title bar) in single invocation
    echo "Applying ast-grep patches..."
    ${ast-grep}/bin/ast-grep scan --inline-rules '${astGrepRules}' --update-all app.asar.contents || {
      echo "✗ ast-grep failed"
      exit 1
    }
    echo "✓ All patches applied with ast-grep"

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

    # Create symlink for claude binary in lib directory so the app can find it
    mkdir -p $out/lib/claude-desktop/bin
    ln -s ${llm-agents.claude-code}/bin/claude $out/lib/claude-desktop/bin/claude

    # Create wrapper script
    makeWrapper ${electron}/bin/electron $out/bin/claude-desktop \
      --add-flags "$out/lib/claude-desktop/app.asar" \
      --set DISABLE_AUTOUPDATER 1 \
      --set NODE_ENV production \
      --prefix PATH : "$out/lib/claude-desktop/bin"

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
