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
    runScriptPrefix = {errorOut ? true}: ''
      # Needed for simulink even on wayland systems
      export QT_QPA_PLATFORM=xcb
      # Search for an imperative declaration of the installation directory of matlab
      if [[ -f ~/.config/matlab/nix.sh ]]; then
        source ~/.config/matlab/nix.sh
    '' + pkgs.lib.optionalString errorOut ''else
        echo "nix-matlab-error: Did not find ~/.config/matlab/nix.sh" >&2
        exit 1
      fi
      if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "nix-matlab-error: INSTALL_DIR $INSTALL_DIR isn't a directory" >&2
        exit 2
    '' + ''
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
    # Might be useful for usage of this flake in another flake with devShell +
    # direnv setup. See:
    # https://gitlab.com/doronbehar/nix-matlab/-/merge_requests/1#note_631741222
    shellHooksCommon = (runScriptPrefix {}) + ''
      export C_INCLUDE_PATH=$INSTALL_DIR/extern/include:$C_INCLUDE_PATH
      export CPLUS_INCLUDE_PATH=$INSTALL_DIR/extern/include:$CPLUS_INCLUDE_PATH
      # Rename the variable for others to extend it in their shellHook
      export MATLAB_INSTALL_DIR="$INSTALL_DIR"
      unset INSTALL_DIR
    '';
    # Used in many packages
    metaCommon = with pkgs.lib; {
      homepage = "https://www.mathworks.com/";
      # This license is not of matlab itself, but for this repository
      license = licenses.mit;
      # Probably best to install this completely imperatively on a system other
      # then NixOS.
      platforms = platforms.linux;
    };

    # Generate an src for the python packages - different versions have
    # different hashes
    #
    # TODO: should we create a function that will create matlab-python-package
    # for each matlab version?
    generatePythonSrc = version: pkgs.requireFile {
      name = "matlab-python-src";
      /*
      NOTE: Perhaps for a different matlab installation of perhaps a
      different version of matlab, this hash will be different.
      To check / compare / print the hash created by your installation:

      $ nix-store --query --hash \
          $(nix store add-path $INSTALL_DIR/extern/engines/python --name 'matlab-python-src')
      */
      sha256 = {
        "2022a" = "19v09q2y2liinalwxszq3xq70y6mbicbkvzgjvav195pwmz3s36v";
        "2021b" = "19wdzglr8j6966d3s777mckry2kcn99xbfwqyl5j02ir3vidd23h";
      }.${version};
      hashMode = "recursive";
      message = ''
        In order to use the matlab python engine, you have to run these commands:

        > source ~/.config/matlab/nix.sh
        > nix store add-path $INSTALL_DIR/extern/engines/python --name 'matlab-python-src'

        And hopefully the hash that's in nix-matlab's flake.nix will be the
        same as the one generated from your installation.
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
        install -Dm644 ${./icons/hicolor/256x256/matlab.png} $out/share/icons/hicolor/256x256/apps/matlab.png
        install -Dm644 ${./icons/hicolor/512x512/matlab.png} $out/share/icons/hicolor/512x512/apps/matlab.png
        install -Dm644 ${./icons/hicolor/64x64/matlab.png} $out/share/icons/hicolor/64x64/apps/matlab.png
      '';
      runScript = pkgs.writeScript "matlab-runner" ((runScriptPrefix {}) + ''
        exec $INSTALL_DIR/bin/matlab "$@"
      '');
      meta = metaCommon // {
        description = "Matlab itself - the GUI launcher";
      };
    };
    packages.x86_64-linux.matlab-shell = pkgs.buildFHSUserEnv {
      name = "matlab-shell";
      inherit targetPkgs;
      runScript = pkgs.writeScript "matlab-shell-runner" (
        (runScriptPrefix {
          # If the user hasn't setup a ~/.config/matlab/nix.sh file yet, don't
          # yell at them that it's missing
          errorOut = false;
        }) + ''
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
      '');
      meta = metaCommon // {
        description = "A bash shell from which you can install matlab or launch matlab from CLI";
      };
    };
    # This could have been defined as an overlay for the python3.pkgs attribute
    # set, defined with `packageOverrides`, but this won't bring any benefit
    # because in order to use the matlab engine, one needs to be inside an
    # FHSUser environment anyway.
    packages.x86_64-linux.matlab-python-package = pkgs.python3.pkgs.buildPythonPackage rec {
      # No version - can be used with every matlab version (R2021b or R2021a etc)
      name = "matlab-python-package";
      unpackCmd = ''
        cp -r ${src}/ matlab-python-src
        sourceRoot=$PWD/matlab-python-src
      '';
      patches = [
        # Matlab designed this python package to be installed imperatively, and
        # on an impure system - running `python setup.py install` creates an
        # `_arch.txt` file in /usr/local/lib/python3.9/site-packages/matlab (or
        # alike), which tells the `__init__.py` where matlab is installed and
        # where do some .so files reside. This doesn't suit a nix installation,
        # and the best way IMO to work around this is to patch the __init__.py
        # file to use the $MATLAB_INSTALL_DIR to find these shared objects and
        # not read any _arch.txt file.
        ./python-no_arch.txt-file.patch
      ];
      src = generatePythonSrc "2022a";
      meta = metaCommon // {
        homepage = "https://www.mathworks.com/help/matlab/matlab-engine-for-python.html";
        description = "Matlab engine for python - Nix package, slightly patched for a Nix installation";
      };
    };
    packages.x86_64-linux.matlab-python-shell = pkgs.buildFHSUserEnv {
      name = "matlab-python-shell";
      inherit targetPkgs;
      runScript = pkgs.writeScript "matlab-python-shell-runner" (shellHooksCommon + ''
        export PYTHONPATH=${self.packages.x86_64-linux.matlab-python-package}/${pkgs.python3.sitePackages}
        exec python "$@"
      '');
      meta = metaCommon // {
        homepage = "https://www.mathworks.com/help/matlab/matlab-engine-for-python.html";
        description = "A python shell from which you can use matlab's python engine";
      };
    };
    packages.x86_64-linux.matlab-mlint = pkgs.buildFHSUserEnv {
      name = "mlint";
      inherit targetPkgs;
      runScript = pkgs.writeScript "matlab-mlint-runner" ((runScriptPrefix {}) + ''
        exec $INSTALL_DIR/bin/glnxa64/mlint "$@"
      '');
      meta = metaCommon // {
        homepage = "https://www.mathworks.com/help/matlab/ref/mlint.html";
        description = "Check MATLAB code files for possible problems";
      };
    };
    packages.x86_64-linux.matlab-mex = pkgs.buildFHSUserEnv {
      name = "mex";
      inherit targetPkgs;
      runScript = pkgs.writeScript "matlab-mex-runner" ((runScriptPrefix {}) + ''
        exec $INSTALL_DIR/bin/glnxa64/mex "$@"
      '');
      meta = metaCommon // {
        homepage = "https://www.mathworks.com/help/matlab/ref/mex.html";
        description = "Build MEX function or engine application";
      };
    };
    overlay = final: prev: {
      inherit (self.packages.x86_64-linux)
        matlab
        matlab-shell
        matlab-mlint
        matlab-mex
      ;
    };
    inherit shellHooksCommon;
    inherit targetPkgs;
    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = [
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
