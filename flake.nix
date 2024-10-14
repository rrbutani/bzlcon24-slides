{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: let
    np = nixpkgs.legacyPackages.${system};
  in {
    devShells.default = np.mkShell {
      nativeBuildInputs = with np; [
        to-html
        yarn
      ];
    };
  });
}
