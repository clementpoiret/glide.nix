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
  ffmpeg_7,
  gtk3,
  libGL,
  libXtst,
  libva,
  makeDesktopItem,
  patchelfUnstable,
  pciutils,
  pipewire,
  undmg,
  wrapGAppsHook3,
  nix-update-script,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "glide-browser";
  version = "0.1.56a";

  src =
    let
      sources = {
        "x86_64-linux" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.linux-x86_64.tar.xz";
          sha256 = "0b231ajfwzy7zqip0ijax1n69rx1w4fj5r74r9ga50fi4c63vzpn";
        };
        "aarch64-linux" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.linux-aarch64.tar.xz";
          sha256 = "00r32xfgah4rnwklmgdas07jrxpxpfcnsh60n92krj5wbn2gm74c";
        };
        "x86_64-darwin" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.macos-x86_64.dmg";
          sha256 = "095pxgk6jv9v073bifhx8ragk5r1zg73fdc6rh9qfpw1zxz6597q";
        };
        "aarch64-darwin" = fetchurl {
          url = "https://github.com/glide-browser/glide/releases/download/${finalAttrs.version}/glide.macos-aarch64.dmg";
          sha256 = "0ryx2fhw2a6jggz3b8x6i3hnpvbik8dvq3ppwpwh7gfw9iripczy";
        };
      };
    in
    sources.${stdenv.hostPlatform.system};

  sourceRoot = lib.optionalString stdenv.hostPlatform.isDarwin ".";

  nativeBuildInputs = [
    copyDesktopItems
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    patchelfUnstable
    wrapGAppsHook3
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    undmg
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    adwaita-icon-theme
    alsa-lib
    dbus-glib
    ffmpeg_7
    gtk3
    libXtst
  ];

  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    curl
    libGL
    libva.out
    pciutils
  ];

  appendRunpaths = lib.optionals stdenv.hostPlatform.isLinux [
    "${libGL}/lib"
    "${pipewire}/lib"
  ];

  # Firefox uses "relrhack" to manually process relocations from a fixed offset
  patchelfFlags = lib.optionals stdenv.hostPlatform.isLinux [ "--no-clobber-old-sections" ];

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ ffmpeg_7 ]}"
      --add-flags "--name=''${MOZ_APP_LAUNCHER:-glide-browser}"
      --add-flags "--class=''${MOZ_APP_LAUNCHER:-glide-browser}"
    )
  '';

  installPhase =
    if stdenv.hostPlatform.isLinux then
      ''
        runHook preInstall

        mkdir -p $out/bin $out/lib/glide-browser-bin-${finalAttrs.version}
        cp -r * $out/lib/glide-browser-bin-${finalAttrs.version}
        chmod +x $out/lib/glide-browser-bin-${finalAttrs.version}/glide

        ln -s $out/lib/glide-browser-bin-${finalAttrs.version}/glide $out/bin/glide
        ln -s $out/bin/glide $out/bin/glide-browser

        install -D $out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default/default16.png \
          $out/share/icons/hicolor/16x16/apps/glide-browser.png
        install -D $out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default/default32.png \
          $out/share/icons/hicolor/32x32/apps/glide-browser.png
        install -D $out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default/default48.png \
          $out/share/icons/hicolor/48x48/apps/glide-browser.png
        install -D $out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default/default64.png \
          $out/share/icons/hicolor/64x64/apps/glide-browser.png
        install -D $out/lib/glide-browser-bin-${finalAttrs.version}/browser/chrome/icons/default/default128.png \
          $out/share/icons/hicolor/128x128/apps/glide-browser.png

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/Applications $out/bin
        cp -r Glide.app $out/Applications/

        ln -s $out/Applications/Glide.app/Contents/MacOS/glide $out/bin/glide
        ln -s $out/bin/glide $out/bin/glide-browser

        runHook postInstall
      '';

  desktopItems = [
    (makeDesktopItem {
      name = "glide-browser";
      exec = "glide-browser %U";
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
        "application/pdf"
        "application/json"
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

  passthru = {
    ffmpegSupport = true;
    gssSupport = true;
    inherit gtk3;
    updateScript = nix-update-script {
      extraArgs = [
        "--url"
        "https://github.com/glide-browser/glide"
      ];
    };
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
