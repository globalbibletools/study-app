{
  description = "Flutter development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    android-nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;

          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        android-sdk = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          platform-tools
          build-tools-36-0-0
          platforms-android-35
          platforms-android-36
          emulator
          system-images-android-36-google-apis-x86-64
          ndk-28-2-13676358
          cmake-3-22-1
        ]);
      in
      {
        devShells.default = pkgs.mkShell {

          packages = with pkgs; [
            flutter
            dart
            jdk17
            android-sdk
            gradle
            git
            pkg-config
            clang
            cmake
            ninja
            rsync
          ];

          ANDROID_HOME = "${android-sdk}/share/android-sdk";
          ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";

          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android-sdk}/share/android-sdk/build-tools/36.0.0/aapt2";

          JAVA_HOME = pkgs.jdk17;

          shellHook = ''
            # Gradle (>= 9) validates that any includeBuild() projectDirectory
            # is writable. The nixpkgs flutter wrapper lives in /nix/store
            # (read-only), and android/settings.gradle.kts does
            #   includeBuild("$flutter.sdk/packages/flutter_tools/gradle")
            # so we materialize a writable copy of the SDK and point
            # flutter.sdk at it.
            export FLUTTER_ROOT="$PWD/.nix-flutter-sdk"
            NIX_FLUTTER_SRC="${pkgs.flutter}"
            STAMP="$FLUTTER_ROOT/.nix-source"

            if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "$NIX_FLUTTER_SRC" ]; then
              echo "Materializing writable Flutter SDK at $FLUTTER_ROOT ..."
              rm -rf "$FLUTTER_ROOT"
              mkdir -p "$FLUTTER_ROOT"
              # -L dereferences symlinks (the sdk-links tree is all symlinks
              # into another nix store path). --chmod makes it writable.
              rsync -a -L --chmod=u+w,Du+wx "$NIX_FLUTTER_SRC/" "$FLUTTER_ROOT/"
              echo "$NIX_FLUTTER_SRC" > "$STAMP"
            fi

            # The top-level bin/dart is the raw Dart VM, which looks for its
            # snapshots next to itself (bin/snapshots). In the Flutter SDK the
            # snapshots live under bin/cache/dart-sdk/bin/snapshots, so without
            # this symlink `dart language-server` (and other dartdev-based
            # subcommands) fail with "Unable to find snapshot:
            # dartdev_aot.dart.snapshot".
            ln -sfn "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots" \
                    "$FLUTTER_ROOT/bin/snapshots"

            export PATH="$FLUTTER_ROOT/bin:$PATH"

            # Keep android/local.properties in sync with the writable SDK.
            if [ -f android/local.properties ]; then
              sed -i "s|^flutter.sdk=.*|flutter.sdk=$FLUTTER_ROOT|" android/local.properties
            fi

            # Writable pub / gradle caches (independent of the SDK fix, but
            # avoids other read-only surprises).
            export PUB_CACHE="$PWD/.pub-cache"

            export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
            export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

            echo "Flutter environment ready (FLUTTER_ROOT=$FLUTTER_ROOT)."
          '';
        };
      });
}
