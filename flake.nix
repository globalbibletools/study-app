{
  description = "Flutter development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    # Can't go any higher than this revision until this github issue is resolved
    # https://github.com/tadfisher/android-nixpkgs/issues/134
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs?rev=220cea3fdab9d47b1eb17774ae7596850f9a69a3";
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
            flutter344
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
            # Writable pub / gradle caches (independent of the SDK fix, but
            # avoids other read-only surprises).
            export PUB_CACHE="$PWD/.pub-cache"

            export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
            export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
          '';
        };
      });
}
