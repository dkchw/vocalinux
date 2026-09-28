{
  description = "Vocalinux: Voice dictation for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          python = pkgs.python3;

          pywhispercpp = python.pkgs.buildPythonPackage rec {
            pname = "pywhispercpp";
            version = "1.5.0";
            pyproject = true;
            src = pkgs.fetchurl {
              url = "https://files.pythonhosted.org/packages/1c/43/8778f0685a4d32d74efdfa78fc5f745ca9998d96f8121dbf7793db2da5d3/pywhispercpp-1.5.0.tar.gz";
              hash = "sha256-WqVMc+yWYX2XqlGdu/gX5EJV7d2b1S7hJDvmECjb0Bg=";
            };
            postPatch = ''
              substituteInPlace pyproject.toml \
                --replace-warn '"ninja",' "" \
                --replace-warn '"cmake>=3.12",' "" \
                --replace-warn '"repairwheel",' ""
              echo "${version}" > version.txt
            '';
            env = {
              PYWHISPERCPP_VERSION = version;
              NO_REPAIR = "1";
              CMAKE_ARGS = "-DCMAKE_SKIP_BUILD_RPATH=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DCMAKE_INSTALL_RPATH=$ORIGIN";
            };
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              pkgs.patchelf
              python.pkgs.setuptools
              python.pkgs.setuptools-scm
              python.pkgs.wheel
            ];
            propagatedBuildInputs = with python.pkgs; [
              numpy
              requests
              tqdm
              platformdirs
            ];
            postInstall = ''
              find "$out/${python.sitePackages}" -type f -name "*.so*" | while read -r so; do
                patchelf --set-rpath "\$ORIGIN:\$ORIGIN/..:${pkgs.stdenv.cc.cc.lib}/lib" "$so" || true
              done
            '';
            dontUseCmakeConfigure = true;
            doCheck = false;
          };

          runtimeLibs = [
            pkgs.portaudio
            pkgs.libayatana-appindicator
            pkgs.gtk3
            pkgs.stdenv.cc.cc.lib
          ];

          runtimeBins = [
            pkgs.xdotool
            pkgs.xclip
            pkgs.wl-clipboard
            pkgs.wtype
            pkgs.ydotool
            pkgs.alsa-utils
          ];

          typelibPaths = [
            "${pkgs.gtk3}/lib/girepository-1.0"
            "${pkgs.libayatana-appindicator}/lib/girepository-1.0"
            "${pkgs.ibus}/lib/girepository-1.0"
            "${pkgs.libnotify}/lib/girepository-1.0"
            "${pkgs.gobject-introspection}/lib/girepository-1.0"
          ];

          vocalinux = python.pkgs.buildPythonApplication rec {
            pname = "vocalinux";
            version = "0.17.0";
            pyproject = true;

            src = ./.;

            nativeBuildInputs = [
              pkgs.gobject-introspection
              pkgs.wrapGAppsHook3
              python.pkgs.setuptools
              python.pkgs.wheel
            ];

            buildInputs = [
              pkgs.gtk3
              pkgs.libayatana-appindicator
              pkgs.ibus
              pkgs.libnotify
            ];

            propagatedBuildInputs = with python.pkgs; [
              pywhispercpp
              pygobject3
              pycairo
              pyaudio
              numpy
              requests
              psutil
              evdev
              pynput
              onnxruntime
            ];

            dontWrapGApps = true;

            preFixup = ''
              makeWrapperArgs+=(
                "''${gappsWrapperArgs[@]}"
                --prefix GI_TYPELIB_PATH : "${pkgs.lib.concatStringsSep ":" typelibPaths}"
                --prefix PATH : "${pkgs.lib.makeBinPath runtimeBins}"
                --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}"
              )
            '';

            postInstall = ''
              install -Dm644 vocalinux.desktop $out/share/applications/vocalinux.desktop
              for icon in resources/icons/scalable/*.svg; do
                install -Dm644 "$icon" "$out/share/icons/hicolor/scalable/apps/$(basename "$icon")"
              done
            '';

            doCheck = false;
          };
        in
        {
          inherit pywhispercpp vocalinux;
          default = vocalinux;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.vocalinux}/bin/vocalinux";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          python = pkgs.python3;
          pywhispercpp = self.packages.${system}.pywhispercpp;

          pythonEnv = python.withPackages (ps: with ps; [
            pywhispercpp
            pygobject3
            pycairo
            pyaudio
            numpy
            requests
            psutil
            evdev
            pynput
            onnxruntime

            pytest
            pytest-cov
            pytest-mock
            pytest-timeout
            mypy
            black
            isort
            flake8
            setuptools
            wheel
            pyyaml
          ]);

          runtimeLibs = [
            pkgs.portaudio
            pkgs.libayatana-appindicator
            pkgs.gtk3
            pkgs.stdenv.cc.cc.lib
          ];

          runtimeBins = [
            pkgs.xdotool
            pkgs.xclip
            pkgs.wl-clipboard
            pkgs.wtype
            pkgs.ydotool
            pkgs.alsa-utils
          ];

          typelibPaths = [
            "${pkgs.gtk3}/lib/girepository-1.0"
            "${pkgs.libayatana-appindicator}/lib/girepository-1.0"
            "${pkgs.ibus}/lib/girepository-1.0"
            "${pkgs.libnotify}/lib/girepository-1.0"
            "${pkgs.gobject-introspection}/lib/girepository-1.0"
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pythonEnv
              pkgs.just
              pkgs.pkg-config
              pkgs.gobject-introspection
              pkgs.gtk3
              pkgs.libayatana-appindicator
              pkgs.ibus
              pkgs.libnotify
              pkgs.portaudio
              pkgs.xdotool
              pkgs.xclip
              pkgs.wl-clipboard
              pkgs.wtype
              pkgs.ydotool
              pkgs.alsa-utils
            ];

            shellHook = ''
              export GI_TYPELIB_PATH="${pkgs.lib.concatStringsSep ":" typelibPaths}:''${GI_TYPELIB_PATH:-}"
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"
              export PATH="${pkgs.lib.makeBinPath runtimeBins}:''${PATH}"
              export PYTHONPATH="$PWD/src:''${PYTHONPATH:-}"

              echo "============================================="
              echo "  Vocalinux Development Environment (Nix)    "
              echo "============================================="
              echo "  App:      python -m vocalinux.main --debug "
              echo "  Tests:    pytest                           "
              echo "  Lint:     just lint                        "
              echo "============================================="
            '';
          };
        }
      );
    };
}
