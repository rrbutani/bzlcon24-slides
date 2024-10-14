---
transition: fade-out
---

# Absolute Paths: The Use Case

```bash {all|8-9}
#!/usr/bin/env bash

set -euo pipefail

readonly inp="$1"
readonly out="$2"

readonly prelude=/nfs/projects/foo/latest/assets/prelude
readonly helper_script=/nfs/projects/foo/latest/bin/frob

mkdir -p "$(dirname "$out")"
{
    cat "${prelude}"
    "${helper_script}" < "$inp"
} > "$out"
```

<v-click at="2">

  - in practice, other (less straight-forward) manifestations of this exist:
    + absolute paths embedded in (native) binaries
    + arriving at absolute paths via: `$(dirname $(realpath $input))/../sibling`
    + in shebangs, search paths like `$PATH`, `sys.path`, `+incdir+...`

</v-click>


<!--

First, to give an example of what I mean by "pervasive use of absolute paths", here's a short contrived bash script.

The salient bit here is that two of the resources the script accesses (highlighted) are _morally_ inputs to the script but are not passed in via command line arg or env var — instead the paths are embedded and hardcoded in the tool

In practice this comes up in some less straight-forward ways, including:
  - paths in native binaries
  - tools that arrive at an absolute path from a relative input path and then look at sibling files
  - usage in shebangs

To understand why this is a problem from a correctness perspective we need to take a step back and talk about sandboxing in Bazel.

-->
