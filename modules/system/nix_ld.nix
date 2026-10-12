{ pkgs, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    glibc
    zlib
    zstd

    fuse
    fuse3
    e2fsprogs

    libGL
    libglvnd
    vulkan-loader
    wayland
    libxkbcommon
    libdrm

    libx11
    libxcursor
    libxrandr
    libxi
    libxrender
    libxext
    libxfixes
    libxcb
    libxau
    libxdmcp
    libxshmfence
    libxxf86vm
    libxinerama
    libxscrnsaver
    libxtst

    at-spi2-core

    alsa-lib
    pipewire
    pulseaudio
    libva
    libvdpau
    libsndfile
    flac
    libsamplerate
    libpulseaudio
    fdk_aac
    libvpx
    libwebp
    libass
    ffmpeg

    openssl
    curl
    libssh2
    libssh
    nghttp2
    libnghttp2
    brotli
    libidn2
    libunistring
    gss
    krb5
    keyutils
    libnl
    libpcap
    libsodium

    lz4
    xz
    bzip2
    lzo
    snappy

    libpng
    libjpeg_turbo
    libtiff
    giflib
    librsvg
    libraw
    openjpeg

    harfbuzz
    graphite2
    fribidi
    pcre2
    pcre

    libsecret
    libgcrypt
    libgpg-error
    nss
    nspr
    gmp
    mpfr
    nettle
    libtasn1
    p11-kit

    expat
    libffi
    libxml2
    libxslt
    libcap
    libseccomp
    lvm2
    libapparmor
    libedit
    readline
    ncurses
    util-linux
    libevent
    json_c
    libyaml
    boost
    fmt
    spdlog
    dbus-glib
    libdbusmenu-gtk3

    libopus
    libogg
    libvorbis
    fribidi
    soxr

    cairo
    pango
    gdk-pixbuf
    atk
    gtk3
    gtk2
    glib
    glib-networking
    dbus
    fontconfig
    freetype
    icu
    libepoxy
    pixman
    graphene
    libthai
    libdatrie

    libusb1
    libinput
    libwacom
    libgudev
  ];

  environment.systemPackages = with pkgs; [
    appimage-run
    steam-run
    nix-init
    nix-update
    nix-prefetch
    nix-prefetch-scripts
  ];
}
