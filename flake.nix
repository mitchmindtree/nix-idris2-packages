{
  inputs = {
    nixpkgs.url = "github:/nixos/nixpkgs/nixpkgs-unstable";
    idris2PackDbSrc = {
      url = "github:/stefan-hoeck/idris2-pack-db";
      flake = false;
    };
    idris2 = {
      url = "github:/idris-lang/idris2/0e83d6c7c6ad8b3b98758d6b5ab875121992c44c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    idris2Lsp = {
      url = "github:/idris-community/idris2-lsp/81e70d48b7428034b8bc1fa679838532232b5387";
      inputs.idris.follows = "idris2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      idris2,
      idris2Lsp,
      self,
      ...
    }:
    let
      overlays = [ self.overlays.default ];
      inherit (nixpkgs) lib;
      forEachSystem = lib.genAttrs lib.systems.flakeExposed;
      perSystemPkgs = f: forEachSystem (system: f (import nixpkgs { inherit overlays system; }));

      # Constructor for the packdb package set.
      mkPackdbPackages =
        packdbPackages: libAttr:
        lib.mapAttrs (
          _n: pkg: if builtins.hasAttr "inferred" pkg then pkg.inferred libAttr else pkg
        ) packdbPackages;
    in
    {
      # An overlay that:
      # - replaces `idris2` and related tools with our newer versions and
      # - provides all `packdb` packages behind `idris2Packages.packdb`.
      overlays = {
        default = import ./overlay.nix { inherit idris2 idris2Lsp; };
      };

      # Expose both the idris2 tools and the packdb packages.
      packages = perSystemPkgs (
        pkgs:
        let
          packdbPackages = mkPackdbPackages pkgs.idris2Packages.packdb { withSource = true; };
        in
        {
          inherit (pkgs.idris2Packages) idris2 idris2Lsp idris2Api;
        }
        // packdbPackages
      );

      # Custom output that includes:
      # - `packdb` fns for producing derivations as executable or library, with or without source.
      # - `buildIdris` fn for building idris2 package derivations.
      idris2Packages = perSystemPkgs (pkgs: pkgs.idris2Packages);

      formatter = perSystemPkgs (pkgs: pkgs.nixfmt-rfc-style);

      impureShell =
        {
          system ? builtins.currentSystem,
          src ? /. + builtins.getEnv "PWD",
          ipkgName ?
            let
              fileMatches = lib.filesystem.locateDominatingFile "(.*)\.ipkg" src;
            in
            if fileMatches == null then
              throw "Could not locate an ipkg file automatically"
            else
              let
                inherit (fileMatches) matches path;
                relative = lib.head (lib.head matches);
                absolute = lib.path.append path relative;
              in
              lib.strings.removePrefix ((toString src) + "/") (toString absolute),
        }:
        nixpkgs.legacyPackages.${system}.callPackage ./ipkg-shell.nix {
          inherit src ipkgName;
          inherit (self.idris2PackagesWithSource.${system}) buildIdris' idris2 idris2Lsp;
        };
    };
}
