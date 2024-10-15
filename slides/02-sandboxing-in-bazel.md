---
layout: cover
class: text-center
---

# Sandboxing In Bazel

goal: ensure Correctness

<style>
html:not(.dark) .slidev-layout { background-color: #FFFFFF; }
html.dark       .slidev-layout { background-color: #bf616a; }
</style>

<!--

Broadly speaking the sandbox aims to do a couple of things:
  - protect the host system from potentially malicious build actions
  - ensure that actions declare all of their inputs; i.e. that they are _correct_

For our purposes we're more interested in the latter goal, ensuring correctness.

-->


---
transition: fade-out
layout: two-cols
---

# Execution Strategies
<!-- Comparison of Execution Strategies -->

(ignoring: `remote`, `*worker`, `docker`, _`sandboxfs`_)

<v-clicks at=1>

  1. `standalone`
      + `pwd` = execroot → <font style="color:#bf616a"> _reach other inputs by rel path_ </font>
  1. `processwrapper-sandbox`
      + `pwd` = sandbox dir → <font style="color:#a3be8c"> symlink tree w/subset </font>
  1. `linux-sandbox`/`darwin-sandbox`
      + same staging strategy as ☝️ (<font style="color:#a3be8c">symlink tree</font>)
      + plus: _restricted I/O_, _<u>read-only</u> host filesystem_
  1. "hermetic" `linux-sandbox` 👀
      + `experimental_use_hermetic_linux_sandbox`
      + selective read access to host filesystem
      + starts with an empty `/` filesystem, adds things in
</v-clicks>

::right::

<v-switch at=2>
  <!-- standalone execution -->
  <template #0>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash"><span
      class="line slidev-code-highlighted highlighted">$ bazel build //examples/simple \</span>
<span class="line slidev-code-highlighted highlighted">  --spawn_strategy=standalone -s </span>
<span class="line slidev-code-dishonored  dishonored "><font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.</span>
<span class="line slidev-code-dishonored  dishonored "><font color="#12488B">SUBCOMMAND: </font># //examples/simple:simple</span>
<span class="line slidev-code-highlighted highlighted">(cd <font style="color:#bf616a">$OUTB/execroot/_main</font> &amp;&amp; \</span>
<span class="line slidev-code-highlighted highlighted">  exec env - \</span>
<span class="line slidev-code-highlighted highlighted">    PATH=/bin:/usr/bin:/usr/local/bin \</span>
<span class="line slidev-code-highlighted highlighted">  /bin/bash -c &apos;$COMMAND&apos;)</span>
<span class="line slidev-code-dishonored  dishonored "><font color="#26A269">INFO: </font>Found 1 target...</span>
<span class="line slidev-code-dishonored  dishonored ">Target //examples/simple:simple up-to-date:</span>
<span class="line slidev-code-dishonored  dishonored ">  bazel-bin/examples/simple/out</span>
<span class="line slidev-code-highlighted highlighted"><font color="#26A269">INFO: </font>35 processes: 34 internal, 1 local.</span>
</code></pre>
  </template>

  <!-- processwrapper-sandbox -->
  <template #1>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash"><span
      class="slidev-code-highlighted highlighted">$ bazel build //examples/simple --sandbox_debug \</span>
<span class="slidev-code-highlighted highlighted">    --spawn_strategy=processwrapper-sandbox</span>
<span class="slidev-code-dishonored  dishonored "><font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.</span>
<span class="slidev-code-dishonored  dishonored "><font color="#C01C28"><b>ERROR: </b></font>...: Executing //examples/simple:simple failed:</span>
<span class="slidev-code-highlighted highlighted">(cd <font style="color:#a3be8c">$OUTB/sandbox/processwrapper-sandbox/5/execroot/_main</font> \</span>
<span class="slidev-code-highlighted highlighted">  &amp;&amp; exec env - \</span>
<span class="slidev-code-highlighted highlighted">    PATH=/bin:/usr/bin:/usr/local/bin \</span>
<span class="slidev-code-highlighted highlighted">    TMPDIR=/tmp \</span>
<span class="slidev-code-highlighted highlighted">  <strong><u>$INSTALL_BASE/process-wrapper</u></strong> \</span>
<span class="slidev-code-highlighted highlighted">    --timeout=0 --kill_delay=15 ... \</span>
<span class="slidev-code-highlighted highlighted">    /bin/bash -c &apos;$COMMAND&apos;)</span>
<span class="slidev-code-highlighted highlighted"><font color="#26A269">INFO: </font>3 processes: 2 internal, 1 processwrapper-sandbox.</span>
</code></pre>
  </template>

  <!-- linux-sandbox -->
  <template #2>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash"><span
      class="slidev-code-highlighted highlighted">$ bazel build //examples/simple --sandbox_debug \</span>
<span class="slidev-code-highlighted highlighted">    --spawn_strategy=linux-sandbox</span>
<span class="slidev-code-dishonored  dishonored "><font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.</span>
<span class="slidev-code-dishonored  dishonored "><font color="#A2734C">DEBUG: </font>Sandbox debug output for Genrule //examples/simple:simple:</span>
<span class="slidev-code-highlighted highlighted">(cd <font style="color:#a3be8c">$OUTB/sandbox/linux-sandbox/5/execroot/_main</font> \</span>
<span class="slidev-code-highlighted highlighted">  && exec env - \</span>
<span class="slidev-code-highlighted highlighted">    PATH=/bin:/usr/bin:/usr/local/bin \</span>
<span class="slidev-code-highlighted highlighted">    TMPDIR=/tmp \</span>
<span class="slidev-code-highlighted highlighted">  <strong><u>$INSTALL_BASE/linux-sandbox</u></strong> \</span>
<span class="slidev-code-highlighted highlighted">    -t 15 -w /dev/shm ... \</span>
<span class="slidev-code-highlighted highlighted">    -- $COMMAND)</span>
<span class="slidev-code-highlighted highlighted"><font color="#26A269">INFO: </font>35 processes: 34 internal, 1 linux-sandbox.</span>
</code></pre>
  </template>

  <!-- linux-sandbox, again -->
  <template #3>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash"><span
      class="slidev-code-highlighted highlighted">$ bazel build //examples/simple --sandbox_debug \</span>
<span class="slidev-code-highlighted highlighted">    --spawn_strategy=linux-sandbox</span>
<span class="slidev-code-dishonored  dishonored "><font color="#26A269">INFO: </font>Analyzed target //examples/simple:simple.</span>
<span class="slidev-code-dishonored  dishonored "><font color="#A2734C">DEBUG: </font>Sandbox debug output for Genrule //examples/simple:simple:</span>
<span class="slidev-code-highlighted highlighted">(cd <font style="color:#a3be8c">$OUTB/sandbox/linux-sandbox/5/execroot/_main</font> \</span>
<span class="slidev-code-highlighted highlighted">  && exec env - \</span>
<span class="slidev-code-highlighted highlighted">    PATH=/bin:/usr/bin:/usr/local/bin \</span>
<span class="slidev-code-highlighted highlighted">    TMPDIR=/tmp \</span>
<span class="slidev-code-highlighted highlighted">  <strong><u>$INSTALL_BASE/linux-sandbox</u></strong> \</span>
<span class="slidev-code-highlighted highlighted">    -t 15 -w /dev/shm ... \</span>
<span class="slidev-code-highlighted highlighted">    -- $COMMAND)</span>
<span class="slidev-code-highlighted highlighted"><font color="#26A269">INFO: </font>35 processes: 34 internal, 1 linux-sandbox.</span>
</code></pre>
  </template>


</v-switch>

<v-click at=2>
<hr>
<pre class="terminal shiki vitesse-dark vitesse-light slidev-code" style="font-size:0.8em">
<code class="language-bash">$ tree <font style="color:#a3be8c">$SANDBOX_BASE/$N</font>
<font color="#12488B"><b>$SANDBOX_BASE/$N</b></font>
`-- <font color="#12488B"><b>execroot</b></font>
    `-- <font color="#12488B"><b>_main</b></font>
        |-- <font color="#12488B"><b>bazel-out</b></font>
        |   `-- <font color="#12488B"><b>k8-opt-exec-ST-d57f47055a04</b></font>
        |       `-- <font color="#12488B"><b>bin</b></font>
        |           `-- <font color="#12488B"><b>examples</b></font>
        |               `-- <font color="#12488B"><b>simple</b></font>
        |                   |-- <font color="#2AA1B3"><b>script.sh</b></font> -&gt; <font color="#26A269"><b>$OUTB/execroot/_main/bazel-out/k8-opt-exec-ST-d57f47055a04/bin/examples/simple/script.sh</b></font>
        |                   `-- <font color="#12488B"><b>script.sh.runfiles</b></font>
        `-- <font color="#12488B"><b>examples</b></font>
            `-- <font color="#12488B"><b>simple</b></font>
                `-- <font color="#2AA1B3"><b>BUILD.bazel</b></font> -&gt; $OUTB/execroot/_main/examples/simple/BUILD.bazel
</code></pre>

</v-click>

<!--
     TO DO(terminal): hermetic? ... nah
-->

<!--

There are several different execution strategies that implement sandboxing in Bazel.

From least to most strict we have:

====

standalone

as simple as it gets

unfettered access to the host file system

one important detail is that this strategy executes actions directly in the execroot
  - means that even if only using relative paths, actions can read undeclared inputs and outputs from other Bazel actions

====

process wrapper

name of the game here is symlinks, see bottom right

in practice works pretty well if you can ensure that your tools only use relative paths that don't escape pwd

====

linux-sandbox and darwin-sandbox

====

the "hermetic" linux sandbox

will come back to this one

====

-->
