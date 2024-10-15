---
layout: cover
class: text-center
---

# What's the Solution?

<style>
html:not(.dark) .slidev-layout { background-color: #FFFFFF; }
html.dark       .slidev-layout { background-color: #b48ead; }
/* html.dark       .slidev-layout { background-color: #ebcb8b; } */
</style>


---
layout: two-cols-header
---

# Tying Dependencies to Mounts


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

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/simple \
    --spawn_strategy=linux-sandbox \
    --experimental_use_hermetic_linux_sandbox \
    <strong>--sandbox_add_mount_pair=/{bin,lib,lib64,usr}</strong>
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.
<font color="#C01C28"><b>ERROR: </b></font>examples/simple/BUILD.bazel:26:8: ...
<span></span>
cat: /nfs/projects/foo/latest/assets/prelude: No such file
Target //examples/simple:simple failed to build
<font color="#C01C28"><b>ERROR: </b></font>Build did NOT complete successfully</code></pre>


<v-click>
<hr/>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/simple \
    --spawn_strategy=linux-sandbox \
    --experimental_use_hermetic_linux_sandbox \
    --sandbox_add_mount_pair=/{bin,lib,lib64,usr} \
    <font style="color:#a3be8c"><strong>--sandbox_add_mount_pair=/nfs/projects/foo/latest/assets/prelude</strong></font> \
    <font style="color:#a3be8c"><strong>--sandbox_add_mount_pair=/nfs/projects/foo/latest/bin/frob</strong></font>
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple
<font color="#26A269">INFO: </font>Found 1 target...
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>Elapsed time: 0.157s, Critical Path: 0.02s
<font color="#26A269">INFO: </font>2 processes: 1 internal, 1 linux-sandbox.
<font color="#26A269">INFO: </font>Build completed successfully, 2 total actions
</code></pre>

</v-click>


<!--
we got close with the hermetic linux sandbox: we were able to control access to the host file path... we just weren't able to make the sandbox expose the artifact at the absolute path

we can do this manually using `--sandbox_add_mount_pair` — if we do so, the build succeeds, as we'd expect

fundamentally what we want is to tie these two things together:
  - depending on the artifact
  - and the bind mount being created at execution time

this is more or less what our changes to the hermetic linux-sandbox do...
-->

---

# Strategy: Looking For "External" Symlinks..
--

two main changes to the hermetic `linux-sandbox`:
  - look for "external" symlinks in an action, lower to bind mounts when executing
  - stage in inputs (in the sandbox dir) as symlinks again (instead of hardlinks)
    + failure mode for hardlinks was untenable: large file copies
      * i.e. when sandbox base is on tmpfs/different filesystem than sources



<!--
TO DO(script): new_local_repo, minified
    TO DO(script): bind mounts
    TO DO(script): sandbox invocation
    TO DO(terminal): linux sandbox invocation mount map output?

    nah, it's fine; covered later I think
-->

<!--
two main changes
-->

---
layout: two-cols
---

# Details: Symlink Chains

```shell {all|3,6,9,12,13}
/nfs/projects/foo/latest/assets/prelude
^^^^^^^^^^^^^^^^^
/nfs/projects/foo -> /nfs/special/project/area/foo
/nfs/special/project/area/foo/latest/assets/prelude
^^^^^^^^^^^^
/nfs/special -> /nfs/mutable_space/special
/nfs/mutable_space/special/project/area/foo/latest/assets/prelude
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
/nfs/mutable_space/special/project -> /nfs/a/
/nfs/a/area/foo/latest/assets/prelude
^^^^^^^^^^^^^^^^^^^^^^
/nfs/a/area/foo/latest -> 1.0.0
/nfs/a/area/foo/1.0.0/assets/prelude (file)
```

<v-click at="1">

  - the above 5 paths are collected for bind mounting
    * 4 symlinks, 1 file
  - some tools care!
  - misc: w/o Linux v5.12+, cannot _bind mount_  symlinks
    + [`AT_SYMLINK_NOFOLLOW`](https://man7.org/linux/man-pages/man2/mount_setattr.2.html), otherwise: recreate

</v-click>

::right::


<pre class="terminal shiki vitesse-dark vitesse-light">
<code class="language-bash">$ tree /nfs
<font color="#12488B"><b>/nfs</b></font>
|-- <font color="#12488B"><b>a</b></font>
|   `-- <font color="#12488B"><b>area</b></font>
|       `-- <span style="background-color:#26A269"><font color="#12488B">foo</font></span>
|           |-- <span style="background-color:#26A269"><font color="#12488B">1.0.0</font></span>
|           |   |-- <span style="background-color:#26A269"><font color="#12488B">assets</font></span>
|           |   |   `-- prelude
|           |   `-- <span style="background-color:#26A269"><font color="#12488B">bin</font></span>
|           |       `-- <font color="#26A269"><b>frob</b></font>
|           `-- <font color="#2AA1B3"><b>latest</b></font> -&gt; <span style="background-color:#26A269"><font color="#12488B">1.0.0</font></span>
|-- <font color="#12488B"><b>mutable_space</b></font>
|   `-- <font color="#12488B"><b>special</b></font>
|       `-- <font color="#2AA1B3"><b>project</b></font> -&gt; <font color="#12488B"><b>/nfs/a/</b></font>
|-- <font color="#12488B"><b>projects</b></font>
|   `-- <font color="#2AA1B3"><b>foo</b></font> -&gt; <span style="background-color:#26A269"><font color="#12488B">/nfs/special/project/area/foo/</font></span>
`-- <font color="#2AA1B3"><b>special</b></font> -&gt; <font color="#12488B"><b>/nfs/mutable_space/special</b></font>
</code></pre>


---
layout: two-cols
---

# The View From Starlark
no changes!

```python
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

<v-switch at=0>

<template #1>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ bazel build //examples/simple \
    --spawn_strategy=linux-sandbox \
    --experimental_use_hermetic_linux_sandbox \
    --sandbox_add_mount_pair=/{bin,lib,lib64,usr}
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.
<font color="#C01C28"><b>ERROR: </b></font>examples/simple/BUILD.bazel:26:8: ...
<span></span>
cat: /nfs/projects/foo/latest/assets/prelude: No such file
Target //examples/simple:simple failed to build
<font color="#C01C28"><b>ERROR: </b></font>Build did NOT complete successfully</code></pre>
</template>

<template #2>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ <font style="color:#a3be8c"><strong>bazel-fork</strong></font> build //examples/simple \
    --spawn_strategy=linux-sandbox \
    --experimental_use_hermetic_linux_sandbox \
    --sandbox_add_mount_pair=/{bin,lib,lib64,usr}
<font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.
Target //examples/simple:simple up-to-date:
  bazel-bin/examples/simple/out
<font color="#26A269">INFO: </font>6 processes: 5 internal, 1 linux-sandbox.
</code></pre>
</template>

<template #3>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">linux-hermetic-sandbox-helpers.rs:1837: mount map: (🦀)
<font color="#12488B"><b>/</b></font>
├──<font color="#A347BA">bin</font> -&gt; <i>usr/bin</i>
├──<font color="#A347BA">lib</font> -&gt; <i>usr/lib</i>
├──<font color="#A347BA">lib64</font> -&gt; <i>usr/lib64</i>
├──<font color="#12488B"><b>nfs</b></font>
│   ├──<font color="#12488B"><b>a</b></font>
│   │   └──<font color="#12488B"><b>area</b></font>
│   │       └──<font color="#12488B"><b>foo</b></font>
│   │           ├──<font color="#12488B"><b>1.0.0</b></font>
│   │           │   ├──<font color="#12488B"><b>assets</b></font>
│   │           │   │   └──prelude
│   │           │   └──<font color="#12488B"><b>bin</b></font>
│   │           │       └──frob
│   │           └──<font color="#A347BA">latest</font> -&gt; <i>1.0.0</i>
│   ├──<font color="#12488B"><b>mutable_space</b></font>
│   │   └──<font color="#12488B"><b>special</b></font>
│   │       └──<font color="#A347BA">project</font> -&gt; <i>/nfs/a/</i>
│   ├──<font color="#12488B"><b>projects</b></font>
│   │   └──<font color="#A347BA">foo</font> -&gt; <i>/nfs/special/project/area/foo/</i>
│   └──<font color="#A347BA">special</font> -&gt; <i>/nfs/mutable_space/special</i>
├──<font color="#12488B"><b>tmp</b></font>
│   ├──<font color="#12488B">bazel-execroot</font> (from: <b>$OUTB/execroot</b>)
│   └──<font color="#12488B"><b>bazel-source-roots</b></font>
│       ├──<font color="#A347BA">0</font> -&gt; <i>$INSTALL_BASE/embedded_tools</i> (from: <b>$OUTB/...</b>)
│       ├──<font color="#12488B">1</font> (from: <b>/workarea</b>)
│       └──<font color="#12488B">2</font> (from: <b>$OUTB/external/_main~_repo_rules~foo</b>)
└──<font color="#12488B">usr</font>
</code></pre>
</template>

</v-switch>

<!--

note that the criteria matches `new_local_repository` already...

no changes, really; can just swap out `bazel` for `bazel-fork` and it... works now

note: path is available both at abs path location and is also staged in the bazel execroot (as a symlink)


NOTE: skipping tree view from action for simplicity

 -->

---
disabled: true
---

# Optimization: Immutable Directories
"fuzzy" directory inputs

  - why not just use `--sandbox_add_mount_pair`?
    + for the static graph information; still valuable to know what depends on a thing

<!--

TODO(script): external_deps_filegroup
TODO(script): bazel query output I guess?

lo-prio
 -->

---
disabled: true
---

# Optimization: Excludes

"soft" and "hard"

<!--

bind mount optimization: "morally empty"

TODO(script): external_deps_filegroup


lo-prio
-->

---
transition: fade-out
layout: two-cols
---

# Details: "Splatting"
💢: excludes, asymmetric bind mounts

  - overlayFS semantics but with bind mounts (sort of)
  - why not just use overlayFS?
    + unprivileged use → modern Linux kernel versions

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ ls /tmp/dir
a  b  c  d  e  f
</code></pre>

<hr>

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ linux-sandbox -D /dev/stderr -M /tmp/dir -- ...
sandbox-helpers.rs:1837: mount map:
<font color="#12488B"><b>/</b></font>
└──<font color="#12488B"><b>tmp</b></font>
    └──<font color="#12488B">dir</font>

<b>mounting </b><font color="#12488B"><b>directory</b></font>: /tmp/dir
soft exclude map:
<font color="#12488B"><b>/</b></font>

counts:
  - bind mounts: 1
  - splats: 0
  - mounts from splatting: 0
</code></pre>

::right::

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ linux-sandbox -D /dev/stderr -M /tmp/dir -Z /tmp/dir/f
<font color="#12488B"><b>/</b></font>
└──<font color="#12488B"><b>tmp</b></font>
    └──<font color="#12488B">dir</font>
<b>mounting </b><font color="#12488B"><b>directory</b></font>: /tmp/dir
excluding <font color="#A2734C">file</font> at `&lt;sandbox&gt;/tmp/dir/f`
soft exclude map:
<font color="#12488B"><b>/</b></font>
└──<font color="#12488B"><b>tmp</b></font>
    └──<font color="#12488B"><b>dir</b></font>
        └──f (from: <b>tmp/empty_file</b>)
counts(bind mounts: 2, splats: 0, mounts from splatting: 0)
</code></pre>

<hr>

<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ linux-sandbox -D /dev/stderr -M /tmp/dir -E /tmp/dir/f -- ...
splatting bind mount /tmp/dir due to exclude at /tmp/dir/f
shadowing include at `/tmp/dir/f` with exclude
mount map:
<font color="#12488B"><b>/</b></font>
└──<font color="#12488B"><b>tmp</b></font>
    └──<font color="#12488B"><b>dir</b></font> # 👈 NOTE: splatted!
        ├──a
        ├──b
        ├──c
        ├──d
        ├──e
        └──<font color="#C01C28"><b>f</b></font> (excluded)
counts(bind mounts: 5, splats: 1, mounts from splatting: 6)
</code></pre>

<!--

overlayFS semantics but with bind mounts (kind of)

why not just use overlayFS?
  - unprivileged use requires (somewhat) modern Linux kernel versions

required to support:
  - hard excludes
  - asymmetric bind mounts (where the source path doesn't match the dest path)

-->
