---
# theme id, package name, or local path
# Learn more: https://sli.dev/guide/theme-addon.html#use-theme
theme: default
# theme: seriph

# addons, can be a list of package names or local paths
# Learn more: https://sli.dev/guide/theme-addon.html#use-addon
addons: []

# title of your slide, will inferred from the first header if not specified
title: Perfect Sandboxing in Bazel
# titleTemplate for the webpage, `%s` will be replaced by the slides deck's title
titleTemplate: '%s - Rahul Butani'

# information for your slides, can be a Markdown string
info: false

# author field for exported PDF or PPTX
author: Rahul Butani

# keywords field for exported PDF, comma-delimited
keywords: bazelcon, sandboxing, hermetic

# enable presenter mode, can be boolean, 'dev' or 'build'
presenter: true

# enabled pdf downloading in SPA build, can also be a custom url
download: false

# filename of the export file
exportFilename: sandboxing_bzlcon2024.pdf

# export options
# use export CLI options in camelCase format
# Learn more: https://sli.dev/guide/exporting.html
export:
  format: pdf
  timeout: 30000
  dark: true
  withClicks: true
  withToc: false

# enable twoslash, can be boolean, 'dev' or 'build'
twoslash: true

# show line numbers in code blocks
lineNumbers: true

# enable monaco editor, can be boolean, 'dev' or 'build'
monaco: true
# Where to load monaco types from, can be 'cdn', 'local' or 'none'
monacoTypesSource: local
# explicitly specify extra local packages to import the types for
monacoTypesAdditionalPackages: []
# explicitly specify extra local modules as dependencies of monaco runnable
monacoRunAdditionalDeps: []

# download remote assets in local using vite-plugin-remote-assets, can be boolean, 'dev' or 'build'
remoteAssets: false

# controls whether texts in slides are selectable
selectable: true
# enable slide recording, can be boolean, 'dev' or 'build'
record: dev
# enable Slidev's context menu, can be boolean, 'dev' or 'build'
contextMenu: true
# enable wake lock, can be boolean, 'dev' or 'build'
wakeLock: true
# take snapshot for each slide in the overview
overviewSnapshots: false

# force color schema for the slides, can be 'auto', 'light', or 'dark'
colorSchema: auto
# router mode for vue-router, can be "history" or "hash"
routerMode: history
# aspect ratio for the slides
# aspectRatio: 16/9
# real width of the canvas, unit in px
# canvasWidth: 980
# used for theme customization, will inject root styles as `--slidev-theme-x` for attribute `x`
themeConfig:
  primary: '#5d8392'

# favicon, can be a local file path or URL
favicon: 'https://www.gstatic.com/devrel-devsite/prod/vb4766d511641fb9a17edf27ece72c6c6ca056c75a92d2c9b1f18896d7eaaa135/bazel/images/touchicon-180.png'
# URL of PlantUML server used to render diagrams
# Learn mode: https://sli.dev/features/plantuml.html
plantUmlServer: https://www.plantuml.com/plantuml
# fonts will be auto-imported from Google fonts
# Learn more: https://sli.dev/custom/config-fonts.html
fonts:
  sans: Roboto
  serif: Roboto Slab
  mono: Fira Code

# default frontmatter applies to all slides
defaults:
  layout: default
  transition: slide-up # TODO
  # ...

# drawing options
# Learn more: https://sli.dev/guide/drawing.html
drawings:
  enabled: true
  persist: false
  presenterOnly: false
  syncAll: true

# HTML tag attributes
htmlAttrs:
  dir: ltr
  lang: en

layout: intro
---

<v-switch>
  <template #0>
    <h1>Perfect Sandboxing in Bazel</h1>
    <p>Rahul Butani</p>
  </template>
  <template #1>
    <h1>Perfect Sandboxing in Bazel?</h1>
    <p>Rahul Butani</p>
  </template>
  <template #2>
    <h1><em>Badly Behaved Tools + Bazel?</em></h1>
    <p>Rahul Butani</p>
  </template>
  <template #3>
    <h1>Absolute Paths and Bazel</h1>
    <p>Rahul Butani</p>
  </template>
</v-switch>


<v-click at="1">

Migrating a codebase with some unique constraints:
  - lots of custom/vendor tooling — stuff we can't modify
  - tightly coupled to a common compute environment + shared network filesystem
  - pervasive use of absolute paths in tools, scripts, etc.

</v-click>

<style>
html:not(.dark) .slidev-layout { background-color: #FFFFFF; }
html.dark       .slidev-layout { background-color: #a3be8c; }
/* html.dark       .slidev-layout { background-color: #bf616a; } */
/* html.dark       .slidev-layout { background-color: #d08770; } */
/* html.dark       .slidev-layout { background-color: #ebcb8b; } */
/* html.dark       .slidev-layout { background-color: #b48ead; } */
</style>
<!-- TODO: colored slides for the start of each section? -->

<!--

I'm here today to talk about sandboxing in Bazel.

This talk isn't a migration story but it starts in what's probably a familiar place for many of you.

I work at a hardware company, on a team that designs CPUs. About a year and a half ago we began migrating an existing codebase over to Bazel.

Key motivation: correctness.

There were a few interesting things about this codebase:
  - custom tooling — stuff we can't modify
  - tightly coupled to NFS
  - as a result, pervasive use of absolute paths in tools, scripts, input files, and flows

This was challenging because the use of absolute paths effectively negated Bazel's correctness guarantees.

So, in a sense that's what this talk is really about: absolute paths and Bazel.

-->

---
transition: fade-out
layout: intro
---

# Agenda

  - what's the problem?
  - why is it a problem
  - our sandbox extensions
  - using the extensions in practice
  - takeaways, applicability for the ecosystem

<style>
li {
  font-size: 22px;
}
</style>

<!--

In this talk I'll go over:
  - where absolute paths are used and what the use case we're trying to address is
  - why this causes correctness issues and what this has to do with sandboxing
  - how we extended the Bazel sandbox to address this use case
  - what using these extensions looks like in practice
  - and some takeaways for the broader ecosystem

 -->

---
src: ./slides/01-background-and-use-case.md
transition: fade-out
---
---
src: ./slides/02-sandboxing-in-bazel.md
---
---
src: ./slides/03-the-problem.md
---
---
src: ./slides/04-the-solution.md
---
---
src: ./slides/05-using-it-in-practice.md
---
---
src: ./slides/06-takeaways-and-other-angles.md
---
---
src: ./slides/07-fin.md
---
---
src: ./slides/08-questions.md
---

<!-- TODO: consider lower case titles -->

<!-- TODO: --slidev-transition-duration -->
