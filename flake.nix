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
      # -desktop is needed, see:
      # https://www.mathworks.com/matlabcentral/answers/20-how-do-i-make-a-desktop-launcher-for-matlab-in-linux#answer_25
      exec = "@out@/bin/matlab -desktop %F";
      icon = "matlab";
      # Most of the following are copied from octave's desktop launcher
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeTypes = [
        "text/x-octave"
        "text/x-matlab"
      ];
      keywords = [
        "science"
        "math"
        "matrix"
        "numerical computation"
        "plotting"
      ];
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
      runScript = runScriptPrefix + ''
        cat <<EOF
        ============================
        welcome to nix-matlab shell!

        To install matlab:
        ${nixpkgs.lib.strings.escape ["`" "'" "\"" "$"] (builtins.readFile ./install.adoc)}

        4. Finish the installation, and exit the shell (with \`exit\`).
        5. Follow the rest of the instructions in the README to make matlab
           executable available anywhere on your system.
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
    packages.x86_64-linux.matlab-mex = pkgs.buildFHSUserEnv {
      name = "mex";
      inherit targetPkgs;
      runScript = runScriptPrefix + ''
        exec $INSTALL_DIR/bin/glnxa64/mex "$@"
      '';
    };
    overlay = final: prev: {
      inherit (self.packages.x86_64-linux) matlab matlab-shell matlab-mlint matlab-mex;
    };
    # Might be useful for usage of this flake in another flake with devShell +
    # direnv setup. See:
    # https://gitlab.com/doronbehar/nix-matlab/-/merge_requests/1#note_631741222
    shellHooksCommon = runScriptPrefix + ''
      # To `import matlab` inside the Python that's inside the dev shell
      export PYTHONPATH="$INSTALL_DIR/extern/engines/python/dist"
      export C_INCLUDE_PATH=$INSTALL_DIR/extern/include:$C_INCLUDE_PATH
      export CPLUS_INCLUDE_PATH=$INSTALL_DIR/extern/include:$CPLUS_INCLUDE_PATH
      # Rename the variable for others to extend it in their shellHook
      export MATLAB_INSTALL_DIR="$INSTALL_DIR"
      unset INSTALL_DIR
    '';
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
