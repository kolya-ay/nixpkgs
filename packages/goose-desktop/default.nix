{ pkgs }:

with pkgs;

buildNpmPackage rec {
  pname = "goose-desktop";
  version = "1.11.0";

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = "sha256-0pDJp/sWFn16HlWU+OYk0K9kIbNohC8NckZywinBRH8=";
  };

  sourceRoot = "${src.name}/ui/desktop";

  npmDepsHash = "sha256-r0DJnjOMmZJzKj5gAndIlxXsSH+ucNgP+yZl2qTRTZc=";

  makeCacheWritable = true;

  nativeBuildInputs = [
    makeWrapper
    nodejs
  ];

  # Skip the default npm build (which runs electron-forge make)
  dontNpmBuild = true;

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };

  # Manually build the Vite application
  buildPhase = ''
    runHook preBuild

    # Generate API types
    npm run generate-api

    # Since the vite configs are empty (they rely on electron-forge plugin),
    # we need to build the files directly with explicit configurations
    # Build each to separate directories to avoid vite clearing the output dir

    # Build main process (Electron main process)
    npx vite build \
      --config vite.main.config.mts \
      --mode production \
      --ssr src/main.ts \
      --outDir .vite/build-main

    # Build preload script (runs in renderer but has Node access)
    npx vite build \
      --config vite.preload.config.mts \
      --mode production \
      --ssr src/preload.ts \
      --outDir .vite/build-preload

    # Combine the outputs into final .vite/build directory
    mkdir -p .vite/build

    # Copy main (rename .mjs to .js)
    if [ -f .vite/build-main/main.mjs ]; then
      cp .vite/build-main/main.mjs .vite/build/main.js
      echo "Copied main.js"
    fi

    # Copy preload (already .js or rename from .mjs)
    if [ -f .vite/build-preload/preload.js ]; then
      cp .vite/build-preload/preload.js .vite/build/preload.js
    elif [ -f .vite/build-preload/preload.mjs ]; then
      cp .vite/build-preload/preload.mjs .vite/build/preload.js
    fi

    echo "Final .vite/build contents:"
    ls -la .vite/build/

    # Build renderer (React app)
    npx vite build --config vite.renderer.config.mts --mode production

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create the application directory structure
    mkdir -p $out/lib/${pname}

    # Debug: Check what we have before copying
    echo "Contents of .vite/build before install:"
    ls -la .vite/build/

    # Copy the built Vite output (should be in .vite directory based on forge config)
    cp -r .vite $out/lib/${pname}/

    # Debug: Check what was copied
    echo "Contents of $out/lib/${pname}/.vite/build after install:"
    ls -la $out/lib/${pname}/.vite/build/

    # Copy necessary resources
    cp -r src/images $out/lib/${pname}/
    cp -r src/bin $out/lib/${pname}/ || true  # May not exist in all builds

    # Copy package.json for metadata
    cp package.json $out/lib/${pname}/

    # Copy node_modules that might be needed at runtime
    mkdir -p $out/lib/${pname}/node_modules
    # Copy only production dependencies that might be needed
    # Most deps are bundled by Vite, but some native modules might be needed

    # Create the executable wrapper
    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags "$out/lib/${pname}/.vite/build/main.js" \
      --set ELECTRON_IS_DEV 0

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/block/goose";
    description = "The desktop application for Goose, built with Electron";
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.asl20;
    mainProgram = pname;
  };
}
