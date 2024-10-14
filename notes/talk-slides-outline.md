
  1. title
    + "not a migration story"
    + had trouble with absolute paths when migrating
    + maybe include slide with migration details as bullet points?
      * can fade in/fade out I guess
  2. outline

  3. explanation of the use case
    + show script that uses absolute paths
    + show script that takes absolute path and uses it to discover sibling files
    <!-- + script that emits absolute paths in output? idk -->
  <!-- 3. why would you do this?
    + ... -->

  4. what's the problem here? need to step back and explain sandboxing...
  5. execution strategy overview (bullets)
    <!-- ideally we'd do some fancy fold/collapse stuff here, not sure... -->
    <!-- actually yeah, let's do left/right with bullet list + highlighting on the left and resources on the right -->
    - standalone
    - process-wrapper
    - linux-sandbox/darwin-sandbox
    - hermetic linux-sandbox
      + use spooky colors or something? idk

  6. example script again
    + add in genrule on right
    + make modification on right (terminal)
    + show: doesn't run again (boom icon, correctness issue)
  7. external dep expressed as a label
    + `new_local_repository`
    + symlink tree
  8. back to example w/genrule
    + re-run; show that the correctness issue is solved
  9. problem solved?
    + no! consider the role of the sandbox
    + should guard against undeclared deps
    + show the symlink tree inside, explain the mismatch
      * abs paths vs. relative paths
      * should be using `runfiles` goop, `$(rlocation)`, etc.
  10. ... (hermetic sandbox to the rescue?)
    + okay so we want to disallow unfettered host filesystem access
    + earlier, mentioned there's a thing for that
    + does it work?
      * still no
      * (show CLI w/error)
  11. hermetic sandbox: what's going on under the hood
    + _hardlinks_ or copies
    + show tree
    + downsides:
      * cross filesystem links -> copies, untenable
      * impedance mismatch, not available at abs path; this is our fundamental constraint
  12. why would you do this!?
    + reminder: contrived example... in this case would be easy to change
    + in practice: deeply embedded inside binaries and such
    + show stack off source code examples, etc. maybe (if time)

  13. what's the solution?
    <!-- + code snippet; want to tie the mounting of the abs path to the presence in the dep graph -->
    + back to the example with the hermetic linux sandbox: can add in `--sandbox_add_mount_pair` to expose _just_ this one file but...
      * want to do so in a way that's scoped just to things that express this dependency
      * _maybe_ possible to hack this into the graph with aspects (propagate up) + transitions (apply flags downwards) but... difficult, intrusive
    + instead, we want this to follow dependency edges, be able to express this in an ergonomic way
  14. simple strategy: inspect symlinks, collect necessary paths, lower as bind mounts, keep staging as symlinks
    + bullet points with the above
    + `@ext` example: show symlink, show collected bind mounts, show linux-sandbox invocation
    + recall from earlier what our `new_local_repository` is actually doing — this "look for symlinks in external repos" thing jives nicely with that
  15. details: symlink chains
    + show diagram
    + explain why this is important...
  16. back to code example: previous example now just works
    + on rhs replace `bazel` with `bazel'` and highlight
    + on rhs show `--sandbox_debug` output
    + path is available at both abs path and via the staged symlink
      * show tree output from the action?
  17. optimization: directories that are read-only
    + perf numbers? not sure (TODO)
    + `external_deps_filegroup` macro helper — desire for back-compat
      * show `bazel query` output for raw stuff
  18. optimization: excludes
    + motivation: python as an example
    + can exclude with globs but...bind mount overhead
    + show difference in bind mounts...
      * smaller command lines is the rub
    + (bottom of slide) caveat: obvious concurrent modification issues here...
  19. details: splatting
    + start with directory mount; try to mount into that directory... conflict!
      * how to resolve?
      * **splat**
      * necessary for excludes, to support bind mounts where `src != dest`
    + extended linux-sandbox to handle this splatting
    + morally a bespoke overlay FS using bind mounts; show tree output from hermetic linux sandbox helpers
      * TODO: keep in the `.rs` there! (show a small ferris on screen on the corner of the diagram)
    + link source code?
    + also had to recreate symlinks (including directory symlinks...) manually due to kernel restrictions...
      * (TODO: find flag guy... not supported until xxx version)


  <!-- how practical is it? -->
  20. ... great we have the machinery. what does usage look like?
    + can we use existing rulesets? how burdensome is listing out deps?
    + practical thing to do is to carve out exemptions...
      * i.e. loader, shared objects, etc.
    + (pause)
    + but what if we didn't?
    + slightly out of paranoia but also out of curiosity: what would it take?
    + show nix quote (taking inspiration from the nix approach/community)
    + pretty much an exercise in uncovering latent implicit deps in the bazel ecosystem
    + latent dependency graphs — painful, sure; but heavily automate-able
  21. most cases: happy, can thread deps in through `toolchain` definitions
    + i.e. python, cc_toolchain, perl, etc.
    + show python code example
  22. latent dep graph: shared objects
    + show error when running a binary under bazel
    + comes up _everywhere_
    + show `ldd`
    + (TODO: maybe separate slide)
    + show script input?
    + show script output?
    + sample of generated output
  23. shell/POSIX/command line tools
    + `genrule`, test setup, cc_wrapper, coverage collection, helper scripts for rules, etc.
    + solution: wrappers + injecting args
    + better solution: patch Bazel to make these `label_flag`s (overridable)
    + even better solution? have Bazel model these with toolchains
  24. interpreted language packages
    + another latent graph
    + show interface as code snippet...
    + show error messages? not sure (actually why not)
  25. extra upsides this had for us
    + dep graph that's queryable
      * show graph on rhs
      * (reference other talk? tomorrow morning)
    + modeling stuff without fear (?)
      * i.e. let us model larger "black box" portions of the existing build in Bazel without needing to worry about correctness or unmodelled implicit inputs — sandbox has our back
      * maybe skip this one
    + good incremental migration strategy
      * can fix our tools
      * can run graph queries to figure out what and where the offenders are

  <!-- takeaways -->
  26. should we all do this?
    + absolutely not
    + made sense for our use case, doesn't necessarily make sense, as implemented, for the ecosystem at large
    + to reiterate:
      * lack of control over tools is what made this worthwhile for us
      * in cases where you can assume cooperation from tools to help with hermeticity and reproducibility -> that's probably preferable
      * "if you can fix your tools, fix your tools"
  27. example of tools + ruleset authors protecting you today
    + (show source code on left, cli output on right)
    + C++ inclusion check
      * requires tool support (i.e. `-M`), ruleset support
  28. two paths on the journey to hermeticity:
    + lean in to the Bazel ideal
      * requires "boiling the ocean" w.r.t to getting tools to behave in a hermetic way
        - admirable, leads to a better user experience, more holistic
        - but... not always possible
    + ... or make concessions for abs paths
      * nix community is an interesting reference point here
  29. goal of this talk is to have the conversation
    + I _think_ there are other issues that this addresses/other upsides to this approach
    + but, not sure how broadly applicable
    + here are some examples I could think of:
      * (TODO: maybe split across a couple of slides)
      * guards against accidental dependence of a host system tool in a script leading to "it works on my machine" type things
        - stuff on `$PATH`, stuff in system install dirs
          + essentially just absolute paths or FHS by another name
        - host to host variability in external (untracked) resources -> cache poisoning
        - in a sense: alternative to out-of-band mechanisms for enforcing that these host deps are in sync across machines (i.e. docker containers)
      * dep graph that's queryable, as mentioned
      * potentially interesting for RBE?
        - i.e. nothing requires that src and dest have to be the same...
        - i.e. auto-applied sysroot
        - can just ship the host paths over to the executor, have it bind mount into place for execution
        - maybe interesting in the context of stuff like `rules_nixpkgs` — which we'll hear a lot more about tomorrow — where one of the challenges vis a vis RBE is that nix packages are consumed by absolute path and need to be materialized on executor machines somehow
          + aware that there are more inventive solutions in this space though (NFS) :)
      * reproducibility issues
        - focus here was on hermeticity (i.e. correctness)
          + if a reused output _plausibly_ could be the output of a clean build → reproducibility issue, not hermeticity issue
        - examples are things that don't materially affect the function of the flow; i.e. debug info, comments in codegen with abs paths, timestamps, diagnostic (stdout/stderr) outputs, etc.
        - having sandbox-level enforcement to "sanitize" abs paths in this context could help — similar idea w.r.t. shifting burden away from tool/ruleset authors

  30. fin
    - github fork link
    - demo repo
    - slides repo link
    - (gh icon with `<user>/<repo>` style links)
    - (TODO: enable discussions on demo repo)
    - slack (bazel): rahul butani
    - r <dot> r <dot> butani <at> gmail <dot> com
    - feel free to reach out, eager to hear about your use cases and alternatives!
    - questions?

---

  31. question: aren't the external paths implicitly covered?
    + usually yes, unfortunately not always
      * i.e. `latest` symlink paths
      * mutable locations
    + also consider dynamic stuff like `$(dirname "$(realpath foo)")/../../oops`
      * seems unlikely but I've seen it in practice!
  32. question: coupling to machine/execution environment?
    + i.e. what if those shared object paths change?
    + yes! good point
    + in practice: not an issue for us because we have a fairly strongly out-of-band guarantee that our fleet of machines have the same shared objects and such
      * and in cases where this isn't true we _want_ to error
    + but: not a hard limitation of this approach
      * can do auto-detection (i.e. repo rules) for this stuff
      * or carve out exemptions; i.e. `/usr/lib`, `/lib64` entirely
  33. question: perf impact/overhead
    + just text with numbers
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
  34. question: why not docker?
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

<!-- other kinds of sandbox escapes?
  - realpath + siblings? -->

other upside: no correctness issues in host-to-host variability in external (untracked) resources
  + i.e. don't need "out of band" guarantee

other applicability: other places where you have abs paths and can't change the usage site
