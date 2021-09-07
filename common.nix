/* This list of dependencies is based on the official Mathworks dockerfile for
   R2020a, available at
     https://github.com/mathworks-ref-arch/container-images
*/
pkgs:

(with pkgs; [
  cacert
  alsaLib # libasound2
  atk
  glib
  glibc
  cairo
  cups
  dbus
  fontconfig
  gdk-pixbuf
  #gst-plugins-base
  # gstreamer
  gtk3
  nspr
  nss
  pam
  pango
  python27
  python36
  python37
  libselinux
  libsndfile
  glibcLocales
  procps
  unzip
  zlib

  gcc
  gfortran

  # nixos specific
  udev
  jre
  ncurses # Needed for CLI

  # Keyboard input may not work in simulink otherwise
  libxkbcommon
  xkeyboard_config
]) ++ (with pkgs.xorg; [
  libSM
  libX11
  libxcb
  libXcomposite
  libXcursor
  libXdamage
  libXext
  libXfixes
  libXft
  libXi
  libXinerama
  libXrandr
  libXrender
  libXt
  libXtst
  libXxf86vm
])
