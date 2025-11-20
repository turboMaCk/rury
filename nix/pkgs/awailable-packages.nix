{ pkgs ? import <nixpkgs> {}
, preinstalled-r-packages ? []
}:
let
  full-package-list = builtins.attrNames pkgs.rPackages;
  r-packages-all-json = builtins.toFile "r-packages-all.json"
    (builtins.toJSON full-package-list);

  r-packages-preinstalled-json = builtins.toFile "r-packages-preinstalled.json"
    (builtins.toJSON preinstalled-r-packages);
in
pkgs.stdenv.mkDerivation {
  pname = "r-packages-jsons";
  version = "0.0.1";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/var
    cp ${r-packages-all-json} $out/var/r-packages-all.json
    cp ${r-packages-preinstalled-json} $out/var/r-packages-preinstalled.json
  '';
}
