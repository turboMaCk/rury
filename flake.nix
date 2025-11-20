{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      # 2. Define the overlay. This uses haskellPackages.makeScope to
      # correctly merge your custom packages into the main set.
      overlay = final: prev: {
        haskellPackages = prev.haskellPackages.extend (_: haskellPackagesNew: {
          rury-server = final.haskell.lib.overrideCabal (haskellPackagesNew.callPackage ./nix/pkgs/server.nix {}) {};
        });
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
    in rec {
      devShells.${system}.default = pkgs.mkShell {
        name = "rory-dev";
        inputsFrom = [ packages.${system}.default];
        buildInputs = with pkgs; [ zlib pkg-config ];
      };
      packages.${system} = rec {
        default = server;
        server = pkgs.haskellPackages.rury-server;
      };
    };
}
