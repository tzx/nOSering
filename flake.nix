{
  description = "nosering";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.pkgsCross.riscv64-embedded.mkShell {
          nativeBuildInputs = with pkgs; [
            zig
            zls
            qemu
            gdb
            gcc
          ];
        };
      }
    );
}
