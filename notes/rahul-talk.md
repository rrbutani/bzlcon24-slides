
my name is Rahul and I'm here to talk about sandboxing in bazel
this is not a migration story, but this talk starts in what's probably a familiar place for many of you
i work at a hardware company, on a team that designs cpus
14 months ago I began migrating an existing build system to bazel (mix of make and perl and other bespoke stuff) supporting a team of around 200 engineers
motivations for using bazel were the common ones: correctness and speed, in that order
faced the usual pain points:
  - people were having to do clean builds all the time
faced a lot of the usual challenges, needing to be more explicit about des
accommodate existing flows and legacy code
one of the more unique issues was the prevalence of closed source tools that relied on absolute paths

really what this talk is about is dealing with problematic tooling that doesn't fit with bazela conception of the world but if we're being honest it's mostly about dealing with absolute paths

---

example: build is heavily coupled to nfs, shared compute environment, authors of tools/scripts rely heavily on shared paths for users, often versions are encoded in shebangs using these abs paths, so technically the information is there but not expressed in a way we'd like it

some tools take the realpath of something you pass it and find other files from relative paths based on that

why's this a problem? why does it compromise correctness? we have to take a step back and talk about sandboxing

3-4 sandboxing modes in bazel, least to most strict execution strategy

1. standalone mode unfettered access to host fs, net, system resources. get inputs from paths on disk
2. little more strict is process wrapper sandbox, all about symlinks. in practice no os technology (like namespaces) so we're not hiding any files, but we set up a CWD with a set of files that you use through relpaths. this works pretty well in practice and if your tools cooperate solves most of your problems. also clears ur env. show diagram/tree view of the sylinks that gets constructed
3. platform specific sandbox restricting things like network/shm/process namespace/additional flag to sanitize hostname/username/temp, crucially they still use the same strategy (symlink) trees for constraining the set of file inputs. used by default for local execution. it's pretty good. big omission is the entire host fs is still accessible in read only mode
4. hermetic Linux sandbox, not super well known or frequently used. <!-- goes one step further and disallows any access to the host fs. --> goes one step further: starts with an empty `/`. you do however get a build system wide allowlist of absolute paths that are excepted so you can still use those. a classic example would be your system loader. will come back to this

<!-- ignoring: remote execution, sandboxfs, docker, persistent workers -->

back to our example under default (Linux sandbox) if I ran a script like the one I showed it'd execute just fine. those paths are still accessible, despite not being declared as inputs. if one of those files changed bazel wouldn't know to rerun the action
  - correctness issue meaning: incremental builds don't work as expected, remote caching produces incorrect results

first hurdle is being able to even express these files outside our build system as targets, we do this with repo rules, like new_local_repository

conceptually this is very simple — we're making a "shadow" copy of a directory using symlinks and are putting a BUILD file alongside the symlinks which lets us refer to the files with labels. when doing input change tracking, bazel will inspect the symlink's target's contents treating them as inputs (shown a new local repo invocation with the path from the example and the symlinks tree it creates)

depending on this is simple: (here's a genrule that depends on that abs path would look now...)

and... this actually does solve our undeclared input issue!

but there's still a problem here... in theory this looks great but it's actually not sufficient. consider the role of the sandbox: you shouldn't have to know about this dependency

what happens when we add this dep (show diff of symlinks tree). now u have an extra symlinks to the absoath to that implicit dep, but out script isn't actually using it via that symlink it's still doing an end run around the build system and accessing it through its abspath. what do we do about this? use the secret 4th sandboxing mode that I mentioned earlier.

it disallows access, so in the example given the hermetic sandbox it has to use hardlinks (or if your target is on a different fs it makes a copy which is disastrous)

if u tried the genrule under the hermetic sandbox it'd fail to execute, cuz even tho bazel knows it needs to make that path accessible, it does so at a relpath and the script accesses and it at the abspath so there's an impedance mismatch still

surely some of u are wondering why does this problem even exist, can't we just change the script to not use the abspath, just fix the tools? don't have a great answer for you, the unfortunate reality at least in the industry that I work in is that there is a large volume of closed source or vendor tooling that your infra team doesn't have the resources or context to sufficiently rework

the solution we landed on is was super simple, just like the hermetic linux sandbox, we start with an empty root filesystem (mount namespaces) and then rather than hardlinking in the paths referenced outside of the bazel repositories, we leave the relative symlinks that bazel normally uses, and then we make just that individual path available at it's original location using bindmounts

conceptually that's all there is to this solution. in practice there's some more details. for the sake of performance we do a few things. ~~one is that we only do this walking of symlinks and bindmounting for stuff in external repos (not the main workspace)~~ one thing is that we actually go and reify entire symlink chains (i found a tool that actually relied on this!). this turns out to be surprisingly thorny, because particularly in older linux kernel versions (like the one my employer happens to use) they can't tell the mount syscall to not resolve the source (and dest?) argument of the mount (which blows through all your symlinks). as an example of this... a->{b,c,d,e,f}->g only wanna make b available. performance problem, consider python stdlib, 10's of thousands of files. takes a long time to symlink in all of these. sandbox overhead skyrockets to 600ms (which you pay on every action). regular python toolchains modeled in bazel also have this issue, they actually give up on hermetic sandboxing and just use the paths directly. wanna support excludes for performance

morally what we're here is basically our own overlay filesystem... without directly using overlayfs because of our kernel environment and hpc environment restrictions. fabian and some other people talked about doing this to solve their hermetic tmp issues. for us we make a tree (splatting) which is the output of our hermetic sandbox in debug mode.

that coveres execution side changes. from the user interface side the changes are actually pretty minimal. under the hood we're looking for any artifact in an external repository that is a symlink to a file on disk and going and discovering all the symlinks that it accesses and soforth. so there isn't that much that needs to change in your BUILD file. the example from earlier where you specify the new_local_repository doesn't need any changes to work under this sandbox. there are a couple of additions to surface some niche bits of functionality around mounting directories (rather than files) and excludes that we smuggled through an undocumented attribute of the filegroup rule ("include" if you're curious). the goal was to maintain backwards compatibility so we didn't lock ourselves into our own bazel fork.

we have a nice little "deps_filegroup" macro to abstract these away, here's an example of what a usage of that looks like

upside of this approach is that we're actually tracking these file deps in the depgraph, an alternative solution would have been strace or adding allowlist sandbox mounts. maybe you could have done something like propagate that info with transitions. i'll call the strace based post-processing flows "checkers" and those are definitely less maintainable and you don't get the same kind of structured information you get from including them in the graph.

alright, we've got all this machinery for expressing and enforcing these host filesystem deps, that's all well and good. in practice how well does this work? is it practical? is it slow? can you track them all down? can you still use existing things in the ecosystem like rulesets while using this aggressive sandboxing. surprisingly more or less yes, it's not to painful and it's something we were able to do. just like the hermetic linux sandbox lets you carve out exceptions this one also lets you add escape hatches, and you probably should for libld64, etc, shared object deps, etc. however as an experiment and out of a little bit paranoia also just to see if it was possible, we tried to see how far we could take it. I was looking at the nix ecosystem and their sandbox at the time (put quote up on screen without addressing it). they do manage to achieve a very high degree of hermeticity.

what are the big kind of implicit deps we have in bazel?
- shared objects. some rulesets try to provide static toolchains that don't have any of these deps but that generally isn't the case. things like your python interpreter will depend on libc/zlib/ssl/etc. this is an example of where listing out these deps would be super painful. there's essentially a depgraph between your shared objects. luckily this is amenable to automation, we wrote a script that takes a list in starlark of binaries at absolute paths (we have it the list of binaries in our "standard compute environment") and it'd construct starlark descriptions of those graphs. the way this gets consumed is that when you go use one of these things (like say the perl toolchain) anything that ends up using this target get's all the fs paths mapped in, so in a pybinary that you called in a genrule you'd have "libs" mapped in. we're threading through this dep with the toolchain, so you get to plug into the existing ruleset without any changes, your toolchain definition enacpsulates the complexity
- shell stuff (bash/posix tool and coreutils). this is trickier, there's a few of these. every genrule, run_shell_acction, and internal scripts that rulesets use, such as the test-setup script that every test rule uses. one way to solve this would be a shell toolchain defined in bazel that got piped to the right places. turns out you can override implicit attributes in bazel by forging $ with bzl file macros)
- language ecosystem specific packages like python libraries. also applies to perl/ruby/etc. the way it works is you fetch your python deps from pypi or whatever package registry and invoke pip install or the moral equivalent in a repo rule. here we're wrapping a custom installation that has company specific python packages. we still wanted the ability to list deps on particular python packages and not just making a global package universe visible to everything, so we invented a little way to list lists of deps (srry missed a bit here) and here's an example with what that looks like in a build file

we focused thus far on correctness issues, which is the most important impediment to using tools like these in bazel, but it's not the whole story. my mini-sermon about hermeticity/reproducability. latter is not about correctness. rule of thumb is that if the output that you end up using feasibly could have been the output of a clean build then you haven't violated hermeticity. for reproducability there are other considerations for example the obvious determinism things like rand/thread interleaving/hashmap ordering, but also the absolute paths of _output_ artifacts, or diagnostics, or source_artifact, or exec_root path. while not crucial to maintaining correcetness this is also something we can mitigate in a similar way by bindmounting output paths and such at a stable location.

### takeaways
should we all be doing this? no, fix ur tools if you can. only made sense for us because we couldn't. we didn't upstream it because it's kind of a hacky roundabout solution which we're not sure if it's even the right approach.
mandating that tools operate in the relative path universe is
gram Christiansen "there's a huge corpus of brown bag software that will simply never run under the nix sandbox"
today the way we ensure correctness is by putting the onus on tools, so we see these issues arise with tools that are written to be portable, for example in c and c++ you can include headers that are in your system install paths (like /usr/lib/whatever) and today as ruleset authors and people contributing to gcc/clang. today bazel has an explicit check for rules_cc that looks for these system deps and produces a warning (like this). my contention is that if you're using well supported open source you're fine, but there's a large corpus for which taking this kind of care is simply not practical. interesting conversation to be had around ways in which bazel can help meet these tools where they're at without requiring drastic restructurings to work with bazel's conception of the world

i see two paths on the bazel ecosystem's journey to full hermeticity:
  - commit to relative paths everywhere, excise the remaining offenders
    + shell, implicit reliance on POSIX binaries on standard `$PATH` locations
      * can work around this with stuff like `rules_sh`, wrappers to set `$PATH` to point into runfiles, etc.
    + shared object deps
      * mitigations:
        - statically link tools -> hard, not always practical (i.e. python extensions)
        - `LD_LIBRARY_PATH`, `patchelf`, `-rpath ...`, shipping a sysroot
          * still misses the loader (outside of techniques like `reloader` there aren't many ways to work workaround the abs path here...)
            + but this is maybe okay; small surface area for hermeticity issues
    + continue relying on tools to guard against correctness issues:
      * ...
    + including on reproducibility issues re: abs paths
  - alternatively: make some concessions re: absolute path usage in places and grow ways of articulating + enforcing such deps
    + ...

  - interesting contrast with the nix ecosystem where the approach very much _is_ to get tools to conform to the nix ethos (composability at runtime via hooks or wrappers rather than via FHS, insistence on using nix store paths at build time rather than FHS)
    + but: does not push tools towards relative paths

### future plans
couple things to ponder.
one unexpected benefit of detailing this granular stuff is you can query for stuff like "what are all the stuff that uses python 3.6, we need to deprecate it for a security advisory" which you can do now that you track system libraries
  - in our case: also sets us up nicely for incrementally fixing up tools and migrating them away from using absolute paths, where possible

we haven't gotten to the stage where we've enabled rbe yet, and in our case with a homogenous compute environment we're solving this problem out of band, but a common issue is that your RBE machines will have different system libraries, and one way to look at this is that those system libraries are unexpressed deps. people solve this by putting those deps in a docker maintainer but our approach theoretically allows more granular approaches where the host simply ships over all necessary tools/libraries
rules_nixpkgs

alternative to dazel, essentially — having bazel set up the bind mounts
  - right now the mount sources match the mount locations but this isn't technically required... can have a "sysroot" that bazel always uses, independent of the host machine


### backup slides for potential questions
- aren't you already covering all the info you need with ur versioned path
- isn't this coupling you really hard to a particular machine/execution environment
- what's the perf impact/overhead
- did you try to get this upstreamed
-

- why not docker?
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

misc: side benefit: can't accidentally do stuff like depend on stuff being installed (i.e. on `$PATH`)

misc: example of heremtic linux sandbox as it exists today: https://github.com/monogon-dev/monogon/blob/61b97a375aee98f58c13c13be672b442aecc8440/tools/bazel#L156-L183

link issue: https://github.com/bazelbuild/bazel/issues/18377

misc: mention "we'll hear about nix + Bazel RBE"

misc: mention APE as another solution in the space?
  - mention that we'll hear about it later today?
