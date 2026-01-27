{
  lib,
  stdenv,
  fetchurl,
  adwaita-icon-theme,
  alsa-lib,
  autoPatchelfHook,
  copyDesktopItems,
  curl,
  dbus-glib,
  gtk3,
  hicolor-icon-theme,
  libXtst,
  libva,
  makeBinaryWrapper,
  makeDesktopItem,
  patchelfUnstable,
  pciutils,
  pipewire,
  wrapGAppsHook3,
  nix-update-script,
  libGL,
  udev,
  libdrm,
  ffmpeg_7,
  gsettings-desktop-schemas,
  mesa,
  libpulseaudio,
  libxkbcommon,
  vulkan-loader,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "glide-browser";
  version = "0.1.58a";

  src =
    let
      sources = {
        "x86_64-linux" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.linux-x86_64.tar.xz";
          sha256 = "sha256-yut/yXT+BJCFackLSRG7tLBD6m008k0lC62Qwt7aRX8=";
        };
        "aarch64-linux" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.linux-aarch64.tar.xz";
          sha256 = "sha256-K0y5qZUL7PiFyguuJs3ai7kHNoWb9E3aQT57W6J+BGk=";
        };
        "x86_64-darwin" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.macos-x86_64.dmg";
          sha256 = "sha256-DDxSTDWfCSlFZuBiLoQS5Y4o6NA6ZaDM+1Min1IhLXU=";
        };
        "aarch64-darwin" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.macos-aarch64.dmg";
          sha256 = "sha256-GW70sJW0IGZ5LMVCQA+2J4NXMN0Bj4c4G5anBDWZnuU=";
        };
      };
    in
    sources.${stdenv.hostPlatform.system};

  nativeBuildInputs = [
    copyDesktopItems
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.isLinux [
    autoPatchelfHook
    patchelfUnstable
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    adwaita-icon-theme
    alsa-lib
    dbus-glib
    gtk3
    hicolor-icon-theme
    libXtst
    udev
    libGL
    libdrm
    ffmpeg_7
    pipewire
    mesa
    libpulseaudio
    libxkbcommon
    gsettings-desktop-schemas
  ];

  runtimeDependencies = lib.optionals stdenv.isLinux [
    curl
    libva.out
    pciutils
    libGL
    udev
    libdrm
    pipewire
    mesa
    libpulseaudio
    libxkbcommon
    vulkan-loader
  ];

  appendRunpaths = lib.optionals stdenv.isLinux [
    "${lib.getLib pipewire}/lib"
    "${lib.getLib libGL}/lib"
    "${lib.getLib udev}/lib"
    "${lib.getLib libdrm}/lib"
    "${lib.getLib mesa}/lib"
    "${lib.getLib vulkan-loader}/lib"
  ];

  # Firefox uses "relrhack" to manually process relocations from a fixed offset
  patchelfFlags = lib.optionals stdenv.isLinux [ "--no-clobber-old-sections" ];

  preFixup = lib.optionalString stdenv.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${ lib.makeLibraryPath [ 
          ffmpeg_7 
          pipewire 
          vulkan-loader
      ] }"
      # Wayland + portal-based capture
      --set MOZ_ENABLE_WAYLAND 1
      --set MOZ_USE_XDG_DESKTOP_PORTAL 1
      --set GTK_USE_PORTAL 1

      # Critical for PipeWire on Nix: let libpipewire find SPA plugins/modules
      --set SPA_PLUGIN_DIR "$pipewireLib/lib/spa-0.2"
      --set PIPEWIRE_MODULE_DIR "$pipewireLib/lib/pipewire-0.3"

      --set MOZ_LEGACY_PROFILES 1
      --set MOZ_ALLOW_DOWNGRADE 1

      --add-flags "--name=glide-browser"
      --add-flags "--class=glide-browser"
    )
  '';

  unpackPhase = lib.optionalString stdenv.isDarwin ''
    runHook preUnpack

    /usr/bin/hdiutil attach -nobrowse -readonly $src
    cp -r /Volumes/Glide/Glide.app .
    /usr/bin/hdiutil detach /Volumes/Glide

    runHook postUnpack
  '';

  installPhase =
    if stdenv.isLinux then
      ''
        runHook preInstall

        mkdir -p $out/bin $out/share/icons/hicolor/ $out/lib/glide-browser-bin-${finalAttrs.version}
        cp -t $out/lib/glide-browser-bin-${finalAttrs.version} -r *

        # Ensure all binaries and shared objects are executable for autoPatchelfHook
        find $out/lib/glide-browser-bin-${finalAttrs.version} -type f -exec chmod +x {} +

        chmod +x $out/lib/glide-browser-bin-${finalAttrs.version}/glide
        iconDir=$out/share/icons/hicolor
        browserIcons=$out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default

        for i in 16 32 48 64 128; do
          iconSizeDir="$iconDir/''${i}x$i/apps"
          mkdir -p $iconSizeDir
          cp $browserIcons/default$i.png $iconSizeDir/glide-browser.png
        done

        ln -s $out/lib/glide-browser-bin-${finalAttrs.version}/glide $out/bin/glide
        ln -s $out/bin/glide $out/bin/glide-browser

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/Applications
        cp -r Glide.app $out/Applications/

        mkdir -p $out/bin
        ln -s $out/Applications/Glide.app/Contents/MacOS/glide $out/bin/glide
        ln -s $out/bin/glide $out/bin/glide-browser

        runHook postInstall
      '';

  desktopItems = [
    (makeDesktopItem {
      name = "glide-browser";
      exec = "glide-browser --name glide-browser %U";
      icon = "glide-browser";
      desktopName = "Glide Browser";
      genericName = "Web Browser";
      terminal = false;
      startupNotify = true;
      startupWMClass = "glide-browser";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeTypes = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      actions = {
        new-window = {
          name = "New Window";
          exec = "glide-browser --new-window %U";
        };
        new-private-window = {
          name = "New Private Window";
          exec = "glide-browser --private-window %U";
        };
        profile-manager-window = {
          name = "Profile Manager";
          exec = "glide-browser --ProfileManager";
        };
      };
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url"
      "https://github.com/glide-browser/glide"
    ];
  };

  meta = {
    changelog = "https://glide-browser.app/changelog#${finalAttrs.version}";
    description = "Extensible and keyboard-focused web browser, based on Firefox (binary package)";
    homepage = "https://glide-browser.app/";
    license = lib.licenses.mpl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = with lib.maintainers; [ pyrox0 ];
    mainProgram = "glide-browser";
  };
})
