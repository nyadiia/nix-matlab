/*
  This list of dependencies is based on the official Mathworks dockerfile for
  R2020a, available at
    https://github.com/mathworks-ref-arch/container-images
*/
pkgs:

(with pkgs; [
  cacert
  alsa-lib # libasound2
  atk
  glib
  glibc
  cairo
  cups
  dbus
  fontconfig
  gdk-pixbuf
  gst_all_1.gst-plugins-base
  gst_all_1.gstreamer
  gtk3
  nspr
  nss
  pam
  pango
  python3
  libselinux
  libsndfile
  glibcLocales
  procps
  unzip
  zlib

  # These packages are needed since 2021b version
  gnome2.gtk
  at-spi2-atk
  at-spi2-core
  libdrm
  mesa.drivers

  gcc
  gfortran

  # nixos specific
  udev
  jre
  ncurses # Needed for CLI

  # Keyboard input may not work in simulink otherwise
  libxkbcommon
  xkeyboard_config

  # Needed since 2022a
  libglvnd

  # Needed since 2022b
  libuuid
  libxcrypt
])
++ (with pkgs.xorg; [
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
