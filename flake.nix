{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        gems = pkgs.bundlerEnv {
          name = "ikar";
          gemdir = ./.;
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby
          ];
        };
      });
}
