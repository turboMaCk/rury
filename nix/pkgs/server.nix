{ mkDerivation, aeson, base, base16-bytestring, bytestring
, cryptohash-sha256, directory, http-types, lib, process, scotty
, text, utf8-string, wai
}:
mkDerivation {
  pname = "rury";
  version = "0.1.0.0";
  src = ../..;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base base16-bytestring bytestring cryptohash-sha256 directory
    http-types process scotty text utf8-string wai
  ];
  license = lib.licenses.bsd3;
  mainProgram = "rury";
}
