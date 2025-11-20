# RURY

> Are you reproducible yet?

Build reproducible GNU R containers.

*THIS IS JUST A PROTOTYPE*

## Build locally

This project works strictly only on x86_64 Linux with nix installed.
Additionally you'll need Elm compiler which you can get from nixpkgs under `elmPackage.elm`.

Build Package List

```
$ nix-build nix/pkgs/awailable-packages.nix --out-link packages
```

Build frontend

```
$ elm make frontend/Main.elm --optimize
```

Build and run server

```
$ nix run
```
