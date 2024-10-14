
1. title
  + [ ] text fade
  + [ ] crossed out + color animations
2. agenda:
  + what's the problem
  + why does the problem exist
  + our solution
  + solution in practice
  + takeaways, applicability for the ecosystem
3. use case + example
  + couple of scripts
  + [ ] highlight problematic lines/sections
<!-- 3. why would you do this?
  + vomit emoji?
  + centered slide maybe -->

4. explain sandboxing
  + centered: Sandboxing In Bazel
5. execution strategies in Bazel
  + left/right
  + highlight bullets
  + [ ] diagrams on right:
    * [ ] host env vars icon
    * [ ] IPC icon
    * [ ] tmpfs icon
    * [ ] network icon
    * [ ] username icon
    * [ ] hostname icon
    * [ ] file tree view (colored)
      - fade on access disallowed
      - different color on read-only vs. write
    * [ ] symlink tree view?

6. example script
  + genrule (starlark)
  + [ ] terminal with colors
  + [ ] boom icon (correctness issue)
7. external dep repo
  + starlark code
  + [ ] symlink tree again (just terminal with colors)
8. genrule example, again
  + (same stuff but re-run)
9. problem solved?
  + (pause on problem solved center text?, move upwards)
    * or maybe just break this out into its own slide
  <!-- + [ ] symlink tree inside
    * show root filesystem + staged symlink.. -->
10. hermetic linux sandbox
  + [ ] CLI w/command line + error
  + [ ] symlink tree again but with stuff faded/crossed out
11. hermetic sandbox: under the hood
  + [ ] show tree output with `-l` -> hardlinks (or copies)
12. reminder: constraints (title: can't we just change the tools!?)
  + vomit emoji
  + [ ] code snippets? not sure
  + if not: just center?

13. what's the solution?
  + [ ] genrule snippet on the left, CLI on the right
    * highlight `--sandbox_add_mount_pair`
    * and highlight dependency — want to tie these two things together
14. strategy: looking for "external" symlinks
  + [ ] bullets with code blocks: `@ext` file -> symlink on disk at repo path -> collected bind mounts -> linux-sandbox invocation
15. details: symlink chains
  + [ ] show sequence of `ls -l` outputs for the chain
  + [ ] show tree view of bind mount map
  + [ ] show bind mount list
  + bullet points about why this is important
16. code example
  + [ ] previous genrule? (or something..) + CLI on right
    * on rhs replace `bazel` with `bazel'` and highlight
    * on rhs show `--sandbox_debug` output
    * path is available at both abs path and via the staged symlink
      - show tree output from the action?
17. optimization: immutable directories
  + [ ] starlark code example for external_deps_filegroup
  + [ ] starlark code for `bazel query` output
  <!-- + (maybe) chart with numbers... nah -->
18. optimization: excludes
  + [ ] python (or just large directory) tree output
  + [ ] bottom of slide disclaimer
19. details: "splatting"
  + [ ] file tree with dir mount
  + extra bind mount (not symmetric)
  + [ ] conflict (alert) sign on dir mount.. (or just highlight?)
  + [ ] splat bullet point
  + [ ] new file tree post splat
  + [ ] new entry after adding extra bind mount

20. we have the machinery. what does usage look like? (now what? OR using it in practice)
  + [ ] nix quote
21. expressing deps via `toolchain`s
  + [ ] python toolchain code example
22. Latent Dependency Graph: _Shared Objects_
  + [ ] `ldd` output (or `lddtree`) on `/bin/ls`
  + [ ] script input
  + [ ] script CLI output
  + [ ] script code output
23. Implicit Shell/POSIX Dependencies
  + bullet list
  + code snippet: implied attrs
  + code snippet: genrule: highlight `bash` dependency
24. Latent Dependency Graph: Interpreted Language Packages
  + code snippet: user interface
  + code snippet: error message output
25. extra upsides
  + [ ] dep graph (graphviz from bazel) on rhs

26. should we all do this? (takeaways)
27. Today, Onus is on Tools + Rulesets
  + [ ] C++ source on left, CLI output on right
28. Paths on the Journey to Hermeticity
  + left/right; two cols
29. Same Problem, Many Guises
  + just bullets

30. fin
  + [ ] links with icons

---

ext should have two symlinks: 1 easy, 1 with a deep chain
  - let's make one a script that's run that has some deps of its own...
    + data dep on sibling using `realpath`...
