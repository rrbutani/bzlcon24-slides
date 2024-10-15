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

      # NOTE: must keep nixpkgs' `playwright-driver.browsers` in sync with the
      # `playwright-core` package version:
      #
      # as writ, nixpkgs's `playwright-driver.browsers.chromium`: 1091
      # `playwrite-core`: 1.40.0
      #   + https://github.com/microsoft/playwright/commit/0867c3ce5b2f7563c99f279d433885d8ec8423d9
      #   + https://github.com/microsoft/playwright/blob/b8949166dc08e0ae499d08bec004a3f1a4e26ec8/packages/playwright-core/browsers.json
      shellHook = with np; ''
        playwright_chromium_revision="$(${jq}/bin/jq --raw-output '.browsers[] | select(.name == "chromium").revision' ${playwright-driver}/package/browsers.json)"

        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
        export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
        export PLAYWRIGHT_BROWSERS_PATH=${playwright-driver.browsers}
        export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="${playwright-driver.browsers}/chromium-$playwright_chromium_revision/chrome-linux/chrome";
      '';
    };
  });
}
