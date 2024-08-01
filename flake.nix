{
  description = "A `flake-parts` module to wrap packages using nixGL";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixGL = {
      url = "github:nix-community/nixGL/def00794f963f51ccdcf19a512006bd7f9c78970";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixGL, ... }: {
    flakeModule = ./flake-module.nix;
  };
}
