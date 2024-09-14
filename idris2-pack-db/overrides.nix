# Override any packages in the set that need customization beyond the
# `buildIdris` invocation each gets by default. Not every package needs to have
# an entry here, only those needing tweaks. Specify an attribute set here that
# will be merged with the default attribute set and passed to `buildIdris`.
# That means any attribute `buildIdris` explicitly supports can be specified
# here in addition to any attributes supported by `mkDerivation`.
#
# `idris2Packages` is a reference to the final packages of this package set.
{
  lib,
  stdenv,
  pkg-config,
  libxcrypt,
  libuv,
  ncurses5,
  rtl-sdr-librtlsdr,
  sqlite,
}:
{
  base64 = {
    meta.broken = stdenv.isAarch64 || stdenv.isAarch32;
  };

  crypt = {
    buildInputs = [
      libxcrypt
    ];
  };

  ncurses-idris = {
    buildInputs = [
      ncurses5.dev
    ];
  };

  rtlsdr = {
    nativeBuildInputs = [
      pkg-config
    ];

    buildInputs = [
      rtl-sdr-librtlsdr
    ];
  };

  spidr = {
    meta.platforms = lib.platforms.linux;
    # Spidr uses curl to download a library as part of installation.
    # that's not allowed in a sandboxed build environment, so fixing this
    # will mean patching the curl call out and taking care of it as a FOD
    # I suppose.
    meta.broken = true;
  };

  sqlite3 = {
    buildInputs = [
      sqlite.dev
    ];
  };

  sqlite3-rio = {
    buildInputs = [
      sqlite.dev
    ];
  };

  uv = {
    buildInputs = [
      libuv.dev
    ];
  };

  uv-data = {

    preBuild = ''
      patchShebangs --build data/gencode.sh
      patchShebangs --build data/cleanup.sh
    '';

    buildInputs = [
      libuv.dev
    ];
  };
}
