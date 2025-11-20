{ pkgs ? import <nixpkgs> {} }:
let
  full-package-list = builtins.attrNames pkgs.rPackages;
  r-packages-all-json = builtins.toFile "r-packages-all.json"
    (builtins.toJSON flu-package-list);
in
pkgs.stdenv.mkDerivation {
  pname = "available-r-packages-json";
  version = "0.0.1";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/var
    cp ${r-packages-all-json} $out/var/r-packages-all.json
  '';
}
