# Provide an overlay that overrides the nixpkgs versions of the idris2 tools
# with the versions exposed from this flake.
{
  idris2,
  idris2Lsp,
}:
final: prev:
let
  inherit (prev) lib system;
  inherit (import ./packages/idris2.nix { inherit system; }) builtinPackages;

  # The set of all resolved packdb packages.
  packdbResolved = import ./idris2-pack-db/pack-db.nix;

  # Convert resolved packdb attrs into `buildIdris` attrs.
  mkPackdbBuildIdrisAttrs = _name: attr: {
    inherit (attr) ipkgName;
    version = attr.ipkgsJson.version or "unversioned";
    src = prev.fetchgit (attr.src // { fetchSubmodules = false; });
    idrisLibraries = map (depName: final.idris2Packages.packdb.${depName}) (
      lib.subtractLists builtinPackages attr.ipkgJson.depends
    );
    meta.packName = attr.packName;
  };
  packdbAttrs = lib.mapAttrs mkPackdbBuildIdrisAttrs packdbResolved;

  # Read the overrides and apply them.
  overrides = final.callPackage ./idris2-pack-db/overrides.nix { };
  applyOverride = name: attr: lib.recursiveUpdate attr (overrides.${name} or { });
  packdb = lib.mapAttrs applyOverride packdbAttrs;

  # Filter out the set of unbroken package attrs to expose for testing.
  packdbUnbroken =
    let
      deps = n: lib.subtractLists builtinPackages packdbResolved.${n}.ipkgJson.depends;
      libAttrs = n: {
        name = n;
        attr = packdb.${n};
      };
      depBroken = n: attr: lib.any ({ name, attr }: pkgBroken name attr) (map libAttrs (deps n));
      pkgBroken = n: attr: n != "idris2" && ((attr.meta.broken or false) || depBroken n attr);
      supportedPlatform =
        attr:
        !(attr.meta ? "platforms") || builtins.elem prev.stdenv.hostPlatform.config attr.meta.platforms;
    in
    lib.filterAttrs (n: attr: !(pkgBroken n attr) && supportedPlatform attr) packdb;

  # A function for creating a pack-db package derivation.
  # Adds an `inferred` thunk that determines whether to use `executable` or
  # `library` based on the `ipkgJson` `executable` field.
  mkPackdbPackage =
    name: attr:
    let
      pkg = final.idris2Packages.buildIdris attr;
      inferred =
        libAttr:
        if packdbResolved.${name}.ipkgJson ? "executable" then pkg.executable else pkg.library libAttr;
    in
    pkg // { inherit inferred; };

in
{
  idris2Packages = prev.idris2Packages // {
    # Replace nixpkgs' idris2 tools with ours.
    buildIdris = idris2.buildIdris.${prev.system};
    buildIdris' = final.callPackage ./build-idris-prime.nix { };
    inherit (idris2.packages.${prev.system}) idris2 support;
    inherit (idris2Lsp.packages.${prev.system}) idris2Lsp;
    idris2Api = final.callPackage ./packages/idris2-api.nix {
      inherit (final.idris2Packages) buildIdris;
    };

    # Add the `pack-db` packages behind `idris2Packages.packdb`.
    packdb = lib.mapAttrs mkPackdbPackage packdb // {
      # Some `packdb` packages expect `idris2` dependency which is idris2Api.
      idris2 = final.idris2Packages.idris2Api;

      # Test package for building all packdb packages.
      __allUnbroken = prev.symlinkJoin {
        name = "idris2-packdb-all-unbroken";
        paths = lib.attrValues (
          lib.mapAttrs (n: v: (mkPackdbPackage n v).inferred { withSource = true; }) packdbUnbroken
        );
      };
    };
  };

  idris2 = final.idris2Packages.idris2;
  idris2Support = final.idris2Packages.support;
}
