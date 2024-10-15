---
layout: cover
class: text-center
---

# What's the Problem?
where's the Correctness issue?

<style>
html:not(.dark) .slidev-layout { background-color: #FFFFFF; }
html.dark       .slidev-layout { background-color: #d08770; }
/* html.dark       .slidev-layout { background-color: #ebcb8b; } */
/* html.dark       .slidev-layout { background-color: #b48ead; } */
</style>

---
layout: two-cols-header
---

# The Correctness Issue At Hand

::left::

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly inp="$1" out="$2"
readonly prelude=/nfs/projects/foo/latest/assets/prelude
readonly helper_script=/nfs/projects/foo/latest/bin/frob

mkdir -p "$(dirname "$out")"
{
  cat "${prelude}"; "${helper_script}" < "$inp";
} > "$out"
```

```python
# examples/simple/BUILD.bazel
load("@bazel_skylib//rules:native_binary.bzl",
  "native_binary")

native_binary(name = "script", src = ":script.sh")
genrule(
    name = "simple",
    srcs = ["BUILD.bazel"],
    outs = ["out"],
    cmd = "$(execpath :script) $< $@",
    tools = [":script"],
)
```
::right::

<v-click>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em"><code class="language-bash">$ bazel build //examples/simple
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>34 processes: 33 internal, 1 linux-sandbox.
$ cat bazel-bin/examples/simple/out | head -2
hey there bazelcon!
# first 10 lines:
</code></pre>
</v-click>

<v-click>
<hr>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em"><code class="language-bash">$ echo &quot;👋&quot; &gt;&gt; /nfs/projects/foo/latest/assets/prelude
$ bazel build //examples/simple
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>1 process: 1 internal. (🚨🚨🚨)
$ cat bazel-bin/examples/simple/out | head -2
hey there bazelcon!
# first 10 lines:
</code></pre>
</v-click>

<v-click>
<hr>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em"><code class="language-bash">$ bazel clean &>/dev/null
$ bazel build //examples/simple &>/dev/null
$ cat bazel-bin/examples/simple/out | head -2
hey there bazelcon!
👋 (<--- correctness issue! 💥💥💥)
</code></pre>
</v-click>

<!--

TODO: speaker notes

--

so how do we fix this?

the first hurdle is having some way to talk about this "external" dependency in Bazel

 -->


---
layout: two-cols-header
---


# Talking About External Deps
how to model external paths in Bazel?

  - can "reify" external deps w/repository rules: `new_local_repository`
  - conceptually simple: creates a symlink tree


::left::

```python
new_local_repository(
    name = "foo",
    build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "prelude",
    srcs = [":assets/prelude"],
)

filegroup(
    name = "frob",
    srcs = [":bin/frob"],
)
""",
    path = "/nfs/projects/foo/latest/",
)
```

::right::

<br>
<br>

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel query --output=location @foo//:BUILD.bazel
$OUTB/external/_main~_repo_rules~foo/BUILD.bazel:1:1: ...
</code></pre>

<br>

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ tree $OUTB/external/_main~_repo_rules~foo
<font color="#12488B"><b>$OUTB/external/_main~_repo_rules~foo</b></font>
|-- BUILD.bazel
|-- REPO.bazel
|-- WORKSPACE
|-- <font color="#2AA1B3"><b>assets</b></font> -&gt; <span style="background-color:#26A269"><font color="#12488B">/nfs/projects/foo/latest/assets</font></span>
`-- <font color="#2AA1B3"><b>bin</b></font> -&gt; <span style="background-color:#26A269"><font color="#12488B">/nfs/projects/foo/latest/bin</font></span>
</code></pre>

<!--

how do we model external paths in the Bazel build graph?

fortunately there's a pretty clear answer here

to use repo rules like `new_local_repository`

shadow symlink tree for the directory, overlays BUILD files that have targets exposing contents of the directory

Bazel will consider the follow the symlinks to the canonical path when evaluating these files for content changes

-->


---
layout: two-cols-header
---

# Depending on External Artifacts

::left::

```python{all|9-10}
# examples/simple/BUILD.bazel
load("@bazel_skylib//rules:native_binary.bzl",
  "native_binary")

native_binary(
    name = "script",
    src = ":script.sh",
    data = [
        "@foo//:prelude",
        "@foo//:frob",
    ],
)
genrule(
    name = "simple",
    srcs = ["BUILD.bazel"],
    outs = ["out"],
    cmd = "$(execpath :script) $< $@",
    tools = [":script"],
)
```

::right::

<v-click>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em"><code class="language-bash">$ bazel build //examples/simple
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>Elapsed time: 0.608s, Critical Path: 0.05s
<font color="#26A269">INFO: </font>35 processes: 34 internal, 1 linux-sandbox.
<font color="#26A269">INFO: </font>Build completed successfully, 35 total actions
$ cat bazel-bin/examples/simple/out | head -2
hey there bazelcon!
# first 10 lines:
</code></pre>
</v-click>

<v-click>
<hr>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em"><code class="language-bash">$ echo &quot;👋&quot; &gt;&gt; /nfs/projects/foo/latest/assets/prelude
$ bazel build //examples/simple
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>Elapsed time: 0.076s, Critical Path: 0.02s
<font color="#26A269">INFO: </font>2 processes: 1 internal, 1 linux-sandbox. (👍)
<font color="#26A269">INFO: </font>Build completed successfully, 2 total actions
$ cat bazel-bin/examples/simple/out | head -2
hey there bazelcon!
👋 (🎉)
</code></pre>
</v-click>

  <!-- rerunning the same sequence of commands actually _does_ result in Bazel re-running our genrule when the external dep `prelude` is modified -->

<!--
  once we have the a Bazel target for the external dependency, using it is simple

  here's our previous example, now with deps on `prelude` and `frob`

  and now if we rerun the same sequence of commands as before...

  Bazel actually does re-build our genrule target when the external path changes
-->

---
layout: center
class: text-center
---

# Problem Solved?
consider: the role of the sandbox..

<!--

unfortunately this doesn't mean all of our problems are solved

in this case we knew about the missing dependency so we were able to fix it

point of the sandbox is to pre-emptively catch these cases...

so what to do?

well, the issue at hand is that host filesystem access (outside of the sandbox base) wasn't restricted

earlier I mentioned a stricter `linux-sandbox` mode called the hermetic `linux-sandbox` that does restrict host filesystem access

let's try that

-->

---

# The Hermetic Linux Sandbox


<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/simple <strong>--spawn_strategy=linux-sandbox --experimental_use_hermetic_linux_sandbox</strong>
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple (2 packages loaded, 8 targets configured).
<font color="#C01C28"><b>ERROR: </b></font>examples/simple/BUILD.bazel:26:8: Executing genrule //examples/simple:simple failed: (Exit 1): ...
<span></span>
src/main/tools/linux-sandbox-pid1.cc:530: &quot;execvp(/bin/bash, 0x12ae610)&quot;: No such file or directory
Target //examples/simple:simple failed to build
<font color="#C01C28"><b>ERROR: </b></font>Build did NOT complete successfully
</code></pre>

<v-click>
<hr>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/simple --spawn_strategy=linux-sandbox --experimental_use_hermetic_linux_sandbox \
    <strong>--sandbox_add_mount_pair=/{bin,lib,lib64,usr}</strong>
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple (0 packages loaded, 0 targets configured).
<font color="#C01C28"><b>ERROR: </b></font>examples/simple/BUILD.bazel:26:8: Executing genrule //examples/simple:simple failed: (Exit 1): ...
<span></span>
cat: /nfs/projects/foo/latest/assets/prelude: No such file or directory (🤔)
Target //examples/simple:simple failed to build
<font color="#C01C28"><b>ERROR: </b></font>Build did NOT complete successfully</code></pre>
</v-click>

<!--

TODO: speaker notes

-->

---
layout: two-cols-header
zoom: 1.0
---

# Hermetic Linux Sandbox: Under the Hood

  - staging strategy for the hermetic `linux-sandbox`: [hardlinks](https://github.com/bazelbuild/bazel/blob/00fdb673ba8276e83f1c821a7f93aab7038377e2/src/main/java/com/google/devtools/build/lib/sandbox/HardlinkedSandboxedSpawn.java)
    + falling back to file copies (if cross-filesystem)

<hr>

::left::

##### regular linux sandbox dir:

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ tree $OUTB/sandbox/linux-sandbox/17/execroot/_main
<font color="#12488B"><b>$OUTB/sandbox/linux-sandbox/17/execroot/_main</b></font>
|-- <font color="#12488B"><b>bazel-out</b></font>
|   `-- <font color="#12488B"><b>k8-opt-exec-ST-d57f47055a04</b></font>
|       `-- <font color="#12488B"><b>bin</b></font>
|           `-- <font color="#12488B"><b>examples</b></font>
|               `-- <font color="#12488B"><b>simple</b></font>
|                   |-- <font color="#2AA1B3"><b>script.sh</b></font> -&gt; <font color="#26A269"><b>$OUTB/execroot/_main/...<!-- bazel-out/k8-opt-exec-ST-d57f47055a04/bin/examples/simple/script.sh --></b></font>
|                   `-- <font color="#12488B"><b>script.sh.runfiles</b></font>
|                       |-- <font color="#12488B"><b>_main~_repo_rules~foo</b></font>
|                       |   |-- <font color="#12488B"><b>assets</b></font>
|                       |   |   `-- <font color="#2AA1B3"><b>prelude</b></font> -&gt; $OUTB/...<!-- execroot/_main~_repo_rules~foo/assets/prelude -->
|                       |   `-- <font color="#12488B"><b>bin</b></font>
|                       |       `-- <font color="#2AA1B3"><b>frob</b></font> -&gt; <font color="#26A269"><b>$OUTB/...<!-- execroot/_main~_repo_rules~foo/bin/frob --></b></font>
|                       `-- <font color="#2AA1B3"><b>_repo_mapping</b></font> -&gt; <font color="#26A269"><b>$OUTB/...<!-- execroot/_main/bazel-out/k8-opt-exec-ST-d57f47055a04/bin/examples/simple/script.sh.repo_mapping --></b></font>
`-- <font color="#12488B"><b>examples</b></font>
    `-- <font color="#12488B"><b>simple</b></font>
        `-- <font color="#2AA1B3"><b>BUILD.bazel</b></font> -&gt; $OUTB/...
</code></pre>

::right::

##### hermetic linux sandbox dir:

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ tree $OUTB/sandbox/linux-sandbox/15/execroot/_main
<font color="#12488B"><b>$OUTB/sandbox/linux-sandbox/15/execroot/_main</b></font>
|-- <font color="#12488B"><b>bazel-out</b></font>
|   `-- <font color="#12488B"><b>k8-opt-exec-ST-d57f47055a04</b></font>
|       `-- <font color="#12488B"><b>bin</b></font>
|           `-- <font color="#12488B"><b>examples</b></font>
|               `-- <font color="#12488B"><b>simple</b></font>
|                   |-- <font color="#26A269"><b>script.sh</b></font>
|                   `-- <font color="#12488B"><b>script.sh.runfiles</b></font>
|                       |-- <font color="#12488B"><b>_main~_repo_rules~foo</b></font>
|                       |   |-- <font color="#12488B"><b>assets</b></font>
|                       |   |   `-- prelude
|                       |   `-- <font color="#12488B"><b>bin</b></font>
|                       |       `-- <font color="#26A269"><b>frob</b></font>
|                       `-- <font color="#26A269"><b>_repo_mapping</b></font>
`-- <font color="#12488B"><b>examples</b></font>
    `-- <font color="#12488B"><b>simple</b></font>
        `-- BUILD.bazel
</code></pre>


<!-- NOTE: not bothering with tree view from inside the action for now... -->

<!--

On the left is the sandbox directory constructed when running with the `linux-sandbox` execution strategy, on the right is the sandbox base for the hermetic `linux-sandbox`

Salient difference is how the inputs are staged: on the left we have symlinks...

On the right we have... what looks like actual files! In reality these are hardlinks.

the reason for this is that
Under the hermetic linux sandbox there's no guarantee that the absolute paths for resources are actually present in the sandbox so... can't use the symlink staging strategy.

-

Issue here is:

Fundamental mismatch in how artifacts are consumed: in both cases, sandbox is surfacing the artifact within the execroot for use via relative path. But our script is trying to consume it at an absolute path.

In the case of the linux-sandbox the use of the absolute path means that the tool does an end run around the sandbox.

For the hermetic linux-sandbox the use of absolute paths means that the tool is not able to consume the artifact even though it has been made available.
-->

---
layout: center
class: text-center
transition: fade-out
---

<!-- # 🤢 Can't We Just Change the Tools!?
unfortunately, no 😔 -->


<v-switch>
  <template #0>

# 🤢 Can't We Just Change the Tools!?
...

  </template>

  <template #1>

# 🤢 Can't We Just Change the Tools!?
unfortunately, no 😔

  </template>
</v-switch>

<!-- <br>

( why would you do this?) -->

<!-- unfortunately, no; can't change them -->

<!-- difference in paths between machines? no, NFS -->

<!--

at this point I'm sure many of you are thinking:

this seems super gross, lots of other reasons to not do this...

can't we just modify the tools to use `runfiles` or take an arg or something?

and you're right -- not ideal

unfortunately don't have a satisfying answer here

in our case the sheer number of tools and other organizational factors made modifying the tools a non-starter

use of NFS makes some of the usual concerns a non-issue

hold your objections for a bit though, my hope is that you'll see some parallels between this problem and issues affecting the ecosystem more broadly

-->
