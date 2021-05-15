{
  description = "Nix files made to ease imperative installation of matlab";

  # https://nixos.wiki/wiki/Flakes#Using_flakes_project_from_a_legacy_Nix
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-compat }: 
  let
    # We don't use flake-utils.lib.eachDefaultSystem since only x86_64-linux is
    # supported
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    targetPkgs = import ./common.nix;
    runScriptPrefix = ''
      #!${pkgs.bash}/bin/bash
      # Needed for simulink even on wayland systems
      export QT_QPA_PLATFORM=xcb
      # Search for an imperative declaration of the installation directory of matlab
      if [[ -f ~/.config/matlab/nix.sh ]]; then
        source ~/.config/matlab/nix.sh
      else
        echo "nix-matlab-error: Did not find ~/.config/matlab/nix.sh" >&2
        exit 1
      fi
      if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "nix-matlab-error: INSTALL_DIR $INSTALL_DIR isn't a directory" >&2
        exit 2
      fi
    '';
    desktopItem = pkgs.makeDesktopItem {
      desktopName = "Matlab";
      name = "matlab";
      # We use substituteInPlace after we run `install`
      exec = "@out@/bin/matlab %F";
      icon = "matlab";
      # Most of the following are copied from octave's desktop launcher
      categories = "Utility;TextEditor;Development;IDE;";
      mimeType = "text/x-octave;text/x-matlab;";
      extraEntries = ''
        Keywords=science;math;matrix;numerical computation;plotting;
      '';
    };
  in {

    packages.x86_64-linux.matlab = pkgs.buildFHSUserEnv {
      name = "matlab";
      inherit targetPkgs;
      extraInstallCommands = ''
        install -Dm644 ${desktopItem}/share/applications/matlab.desktop $out/share/applications/matlab.desktop
        substituteInPlace $out/share/applications/matlab.desktop \
          --replace "@out@" ${placeholder "out"}
        install -Dm644 ${./icons/hicolor/256x256/matlab.png} $out/share/icons/hicolor/256x256/matlab.png
        install -Dm644 ${./icons/hicolor/512x512/matlab.png} $out/share/icons/hicolor/512x512/matlab.png
        install -Dm644 ${./icons/hicolor/64x64/matlab.png} $out/share/icons/hicolor/64x64/matlab.png
      '';
      runScript = runScriptPrefix + ''
        exec $INSTALL_DIR/bin/matlab "$@"
      '';
    };
    packages.x86_64-linux.matlab-shell = pkgs.buildFHSUserEnv {
      name = "matlab-shell";
      inherit targetPkgs;
      runScript = ''
        #!${pkgs.bash}/bin/bash
        # needed for simulink in fact, but doesn't harm here as well.
        export QT_QPA_PLATFORM=xcb
        cat <<EOF
        ============================
        welcome to nix-matlab shell!

        To install matlab:
        ${nixpkgs.lib.strings.escape ["`" "'" "\"" "$"] (builtins.readFile ./install.adoc)}

        4. Finish the installation, and exit the shell (with `exit`).
        5. Continue on with the instructions for making the matlab executable available
           anywhere on your system.
        ============================
        EOF
        exec bash
      '';
    };
    packages.x86_64-linux.matlab-mlint = pkgs.buildFHSUserEnv {
      name = "mlint";
      inherit targetPkgs;
      runScript = runScriptPrefix + ''
        exec $INSTALL_DIR/bin/glnxa64/mlint "$@"
      '';
    };
    overlay = final: prev: {
      inherit (self.packages.x86_64-linux) matlab matlab-shell matlab-mlint;
    };
    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = (targetPkgs pkgs) ++ [
        self.packages.x86_64-linux.matlab-shell
      ];
      # From some reason using the attribute matlab-shell directly as the
      # devShell doesn't make it run like that by default.
      shellHook = ''
        exec matlab-shell
      '';
    };

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.matlab;

  };
}
