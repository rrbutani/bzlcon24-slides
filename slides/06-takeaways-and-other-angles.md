---
layout: cover
class: text-center
---

# Takeaways

and considerations for the ecosystem


<style>
html:not(.dark) .slidev-layout { background-color: #FFFFFF; }
html.dark       .slidev-layout { background-color: #a3be8c; }
</style>


---

# Should We All Do This?
_**no!!**_

  - made sense in our case due to:
    + strong correctness requirements
    + tools with undesirable behavior — not in our control/with lots of unknowns
  - in practice today many builds with Bazel are reasonably hermetic as is — at least for common, well-supported tools and rulesets
  - this also isn't an argument against making tools behave in a more hermetic manner
    + fix your tools, if you can!
      * better UX, more holistic approach, etc.

<!-- not prescriptive

we had special requirements; in practice if you're using well-supported tooling and aren't struggling with hermeticity there isn't a need

...

all of that said, I do think it's worth contrasting this approach with existing ways of enforcing hermeticity past what the sandbox can provide in Bazel today

 -->

---
layout: two-cols
---

# Onus is on Tools, Rulesets, Out-of-Band Solutions

<!-- achieving that  -->
"last mile of hermeticity" _past_ the sandbox

couple of tacks:
  - get tools to conform to the Bazel ideal:
    + i.e. relative paths everywhere
    + examples:
      * checks in tools/rulesets
      * static linking/fat binaries
      * specially designed hermetic toolchains
    + _high effort_: must understand tools deeply
  - or: out-of-band approach to hermeticity; for example:
    + leverage `nix`/`nixpkgs` ecosystem for tools
    + execute in containers (i.e. `dazel`)

::right::

[example](https://github.com/bazelbuild/bazel/blob/9d500781e6313232b10080b3f15dc9b1723bb78e/src/main/java/com/google/devtools/build/lib/rules/cpp/HeaderDiscovery.java): `lib/rules/cpp/HeaderDiscovery.java`


```c++ {all|2}
// NOTE: including an absolute path is "disallowed"
#include "/oops/hey.h"
#include <iostream>

auto main() -> int {
    std::cout << "hello" << std::endl;
    return 1;
}
```

<hr>

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/cc:test
<font color="#26A269">INFO: </font>Analyzed target //examples/cc:test.
<font color="#C01C28"><b>ERROR: </b></font>examples/cc/BUILD.bazel:2:10:
Compiling examples/cc/main.cc failed:
  absolute path inclusion(s) found in rule
  &apos;//examples/cc:test&apos;:
    the source file &apos;examples/cc/main.cc&apos; includes the
    following non-builtin files with absolute paths (if
    these are builtin files, make sure these paths are in
    your toolchain):
      &apos;/oops/hey.h&apos;
Target //examples/cc:test failed to build
<font color="#26A269">INFO: </font>Elapsed time: 8.693s, Critical Path: 0.41s
<font color="#26A269">INFO: </font>9 processes: 9 internal.
<font color="#C01C28"><b>ERROR: </b></font>Build did NOT complete successfully</code></pre>

<!--

today the onus is on tools and ruleset authors and other out-of-band solutions

super interesting because it
  - is essentially papering over a deficiency of the sandbox
  - requires considerable coordination between tools (gcc, clang) and ruleset authors

-->

---
layout: two-cols
disabled: true
---

# Paths on the Journey to Hermeticity

---
transition: fade-out
---

<!-- # Same Problem, Many Guises -->

# Other Potential Use Cases

  - using more detailed host dependency information for lower effort (?) RBE
    + i.e. using the information to build a container — snapshot of the relevant parts of a host
    + or: shipping necessary components in build, putting into "place" during execution on RBE workers
  - "reproducibility" (not hermeticity issues)
    + hermeticity → correctness issue
    + if a clean build _could_ have produced the cached output → reproducibility issue, not hermeticity
      * i.e. timestamps, PID, rand, benign abs paths in comments, etc.
    + stricter sandboxing could help with (for example) normalizing input paths (i.e. `/build/`)
    + similar idea w.r.t. to shifting burden away from tools/ruleset authors
  - ...
    + curious what the community thinks!

<!--

In contrast, the stricter sandboxing solution described in this talk takes a more structured approach to enforcing hermeticity (as least as far as paths go).

Again, in our case this was appealing due to constraints that aren't universally present in the ecosystem — namely having tools beyond our control/comprehension.

But I think there are also other upsides that come from having Bazel builds be more hermetic and from having more dependency information in our Bazel build graphs.

I've listed some on this slide including potentially plugging some other path related reproducibility issues and leveraging the extra information that a strict sandboxing approach provides to provision RBE machine environments — but I'm more interested to hear what the community thinks.

I suspect there are other use case where there's a desire stricter hermeticity guarantees and I'd love to here from folks in the ecosystem about this.

-->
