{ pkgs ? import <nixpkgs> {}
, extra-r-packages ? [ "dplyr" ]
}:
with pkgs;
let
  corePackages =
    [ R coreutils bash gawk ] ++
    (with rPackages; [ Rcpp vctrs rlang R6 generics glue lifecycle magrittr pillar cli tibble pkgconfig tidyselect ]);

  extraRPackages =
    builtins.map
      (name:
        rPackages."${name}"
      ) extra-r-packages;

  nameSuffix = builtins.concatStringsSep "-" extra-r-packages;

  allRPackages = corePackages ++ extraRPackages;

  rPaths = builtins.concatStringsSep ":" (
    builtins.map (p: "${p}/library") allRPackages
  );

  # 2. Define the startup script for creating /tmp and setting TMPDIR
  setupScript = writeShellScript "setup-r-temp" ''
    # Create /tmp and ensure it is writable by all users (1777 sticky bit)
    mkdir -p /tmp
    chmod 1777 /tmp

    # Set the TMPDIR environment variable for R
    export TMPDIR="/tmp"
    export R_LIBS_SITE="${rPaths}"

    # Execute the command passed via config.Cmd (R)
    exec "$@"
  '';
in
pkgs.dockerTools.buildImage {
  name = "r-container--" + nameSuffix;
  tag = "latest";
  diskSize = 4096;
  buildVMMemorySize = 1024;

  copyToRoot = allRPackages;
  config = {
    Entrypoint = [ "${setupScript}" ];
    Cmd = [ "${pkgs.R}/bin/R" ];
  };
}
