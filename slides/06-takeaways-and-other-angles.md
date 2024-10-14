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

...

<!-- not prescriptive

we had special requirements; in practice if you're using well-supported tooling and aren't struggling with hermeticity there isn't a need

...


 -->

---

# Today, Onus is on Tools, Rulesets, Out-of-Band Stuff

achieving that "last mile of hermeticity"

<!-- TODO: find source code in bazel for this and link! -->

<!--

TODO(script): c++ code snippet

<hr>

TODO(terminal): Bazel output

-->

---
layout: two-cols
---

# Paths on the Journey to Hermeticity

---
transition: fade-out
---

# Same Problem, Many Guises

  - "reproducibility" (not hermeticity issues)
    + hermeticity → correctness issue
    + if a clean build _could_ have produced the cached output → reproducibility issue, not hermeticity
      * i.e. timestamps, PID, rand, benign abs paths in comments, etc.
    + stricter sandboxing could help with (for example) normalizing input paths (i.e. `/build/`)
  -

<!--



-->
