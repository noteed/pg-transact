let

  sources = import ./sources.nix;
  defNixpkgs = import sources.nixpkgs { };
  nix-filter = import sources.nix-filter;

in { nixpkgs ? defNixpkgs }:

let
  inherit (nixpkgs.lib.attrsets) getAttrFromPath mapAttrs;

  # Lists all packages made available through this nix project.
  # The format is `{ <pkgName> : <pkgDir> }` (we refer to this as pInfo).
  # The used directory should be the path of the directory relative to the root
  # of the project.
  pkgList = {
    pg-transact = nix-filter {
      root = ../.;
      include = with nix-filter; [
        "pg-transact.cabal"
        "LICENSE"
        (and "src" (or_ (matchExt "hs") isDirectory))
        (and "test" (or_ (matchExt "hs") isDirectory))
      ];
    };
  };

in {
  inherit pkgList;

  # Get an attribute from a string path from a larger attrSet
  getPkg = pkgs: pPath: getAttrFromPath [pPath] pkgs;

  overrides = selfh: superh:
    let
      callCabalOn = name: dir:
        selfh.callCabal2nix "${name}" dir { };

    in mapAttrs callCabalOn pkgList;

  # Tests are run during the build, and they require some setup:
  # - Here we make sure that initdb can create a PostgreSQL cluster in its
  #   home directory (which is normally set to /homeless-shelter).
  # - initdb is available during the tests because we add postgresql in
  #   the build-tools section of the .cabal file.
  testOverrides = self: superh: rec {
    mkDerivation = args: superh.mkDerivation (
      if args.pname == "pg-transact"
      then args // {
        preBuild = ''
          export HOME=$TEMPDIR
        '';
      }
      else args);
  };
}
