{
  inputs = {
    nixpkgs.url = "github:/nixos/nixpkgs/nixpkgs-unstable";
    idris2PackDbSrc = {
      url = "github:/stefan-hoeck/idris2-pack-db";
      flake = false;
    };
    idris2 = {
      url = "github:/idris-lang/idris2/5459e1726582c7326c3846bd98dfaeb9ac25cdfc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      idris2,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forEachSystem = lib.genAttrs lib.systems.flakeExposed;
      ps = forEachSystem (
        system:
        import ./. {
          pkgs = import nixpkgs { inherit system; };
          idris2Override = idris2.packages.${system}.idris2;
          buildIdrisOverride = idris2.buildIdris.${system};
          idris2SupportOverride = idris2.packages.${system}.support;
          inherit system;
        }
      );
    in
    {
      packages = lib.mapAttrs (n: attrs: (attrs.packages // { inherit (attrs) idris2 idris2Lsp; })) ps;
    };
}
