
# Question: Aren't Absolute Paths Implicitly Covered?
if the file referencing the absolute path is tracked...

  + usually yes, unfortunately not always
    * i.e. `latest` symlink paths
    * mutable locations
  + also consider dynamic stuff like `$(dirname "$(realpath foo)")/../../oops`
    * seems unlikely but I've seen it in practice!

---

# Question: Coupling to Machine/Execution Environment?
i.e. what if those shared object paths change?

  + yes! good point
  + in practice: not an issue for us because we have a fairly strongly out-of-band guarantee that our fleet of machines have the same shared objects and such
    * and in cases where this isn't true we _want_ to error
  + but: not a hard limitation of this approach
    * can do auto-detection (i.e. repo rules) for this stuff
    * or carve out exemptions; i.e. `/usr/lib`, `/lib64`, etc. entirely

---

# Question: Perf Impact/Overhead

  + target with ~200 actions, clean build, warm daemon
    * mostly small (subsecond) actions, lots of inputs (python interpreter, 1000s of individual files)
    * something of a worst case scenario
  + regular linux sandbox (Bazel 7.0):
    * no fuzzy dirs: 20.5s to 21s
    * fuzzy dirs: 20.8s to 21.5s
  + strict linux sandbox:
    * no fuzzy dirs: 31.5s (large-ish overhead)
    * fuzzy dirs: 20.4s to 21.1s
  + basically unoptimized right now though; lots of potential for caching:
    * symlink discovery could be modeled in skyframe
    * splatting is recomputed on every invocation; could be cached


---

# Question: Why Not Docker?

  + good question
  + first: compute environment issues — HPC style environment, kernel too old for rootless docker (missing unprivileged overlayFS support)
  + but also: this approach has user-facing downsides
    * docker execution strategy -> slow, lots of copying
    * "dazel"-style (i.e. Bazel inside docker) -> painful for users
      - dev environment inside a container has UX papercuts; not impossible to work around
  + more importantly: doesn't address the fundamental issue
    * baking a container image with the required "external" deps frozen turns this into a release management/dependency issue instead of a build systems issue
      - when an external dep is updated, need to coordinate baking + rolling out a new image
    * ... but it _also_ still doesn't totally address the build issue?
      - if you don't want to tag all cache keys on the image used, need to make the build system aware of these underlying deps in a granular fashion...
      - which brings us back to the enforcement issue

---

# Question: FHS Wrapper At The Action Level?

---
zoom: 0.85
---

# Question: Library Interposers?
what if we just intercept file I/O libc functions to make it _look_ like things are at absolute paths...

  - usual downsides of library interposers apply:
    + doesn't catch tools/scripts/etc. that don't use (dynamically linked) libc routines for file I/O
    + propagating the interposer to children processes is tricky: tools need to _not_ clear `$LD_PRELOAD`
  - framing: two parts to the problem here:
    1. enforcing access limitation, once you know the abs path inputs to an action
    2. "user interface" — expressing absolute path dependencies, preferably in a hierarchical way
  - interposers offer a solution to #1 (and would let us avoid needing to modify the linux sandbox)
    + in practice: need to modify rulesets to use a wrapper that injects the interposer + provides manifest
  - however... no solution for #2 — still need a way to express and gather absolute path deps
    + can build this in starlark (providers, aspects) but... requires changing existing rules to accommodate this
    + contrast with this approach: piggy-backing on existing Bazel artifact dep graphs

  - bottom line: more intrusive, plays less well with the existing ecosystem

---

# Question: Post-Execution Checker?
strace + aspects + validation actions?

  - hard to integrate
  - perf overhead
  - in practice: tools sometimes behave _differently_ under the sandbox
    + i.e. attempting to access `/usr/lib64` but falling back to using a user-supplied directory
    + safer if there isn't a difference between the usual execution environment and the "checker" environment
  - less static graph information?

<!-- ... -->

---

# Question: Can This Work on macOS?

Conceptually yes but have not implemented.

One caveat is that `sandbox-exec` (aka Project Seatbelt) has limitations in how big the regexes detailing filesystem mounts can be — `nix` users, for example, frequently run into issues with this. It seems likely this would be an issue for sandboxing at this granularity as well.
