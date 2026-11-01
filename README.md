This repository houses the logic for generating the javadoc content at
[https://javadoc.scijava.org/](https://javadoc.scijava.org/).

To contribute, please:

1. [fork](https://github.com/scijava/javadoc.scijava.org/fork) the project,
2. make your changes, commit and push,
3. [open a Pull Request](https://help.github.com/articles/creating-a-pull-request/).

## TL;DR: What is generated

1. **Actual javadoc for each component.**
   E.g. `/org.scijava/scijava-common/2.87.1/`. Analogous to javadoc.io,
   but also supports artifacts deployed to maven.scijava.org. And javadoc
   of supported components is unpacked in advance, not on the fly on demand.

2. **Unioned index of all managed components for a particular BOM.**
   E.g. `/org.scijava/pom-scijava/31.1.0/`. Useful for passing as a link to the
   `javadoc` tool, or when you want to access the javadoc for a library
   corresponding to a particular BOM version. Actual class and package javadoc
   is referenced via 301 redirects to the correct component. For example, the
   path:
   ```
   /org.scijava/pom-scijava/31.1.0/net/imglib2/img/Img.html
   ```
   redirects to:
   ```
   /net.imglib2/imglib2/5.12.0/net/imglib2/img/Img.html
   ```
   Because the `net.imglib2.img.Img` class is part of
   `net.imglib2:imglib2:5.12.0`, one of the BOM's managed components.

3. **Toplevel index of available javadoc.**

## Background and rationale

The generated content is designed around the idea of a [Bill of Materials]
(BOM), which provides a list of *managed* components at particular versions
that are tested and working together. By importing the BOM into your build, you
can then depend on any combination of the managed components without explicitly
declaring their versions, and the versions will be inferred from the BOM.

Now suppose you are developing a Java library L that depends on several managed
components: A, B, C, D, etc. One of the steps when building L is to generate
its [javadoc], package it into a JAR file with classifier `javadoc`, and deploy
the resulting `L-x.y.z-javadoc.jar` artifact to a remote Maven repository.

These javadoc artifacts are useful for [IDEs] to browse javadoc on demand from
within the user interface. But there are two major drawbacks:

1. Humans cannot read the javadoc directly in a web browser.

2. The [`javadoc` tool] cannot consume them as links when generating
   downstream javadoc, so your library L will not have hyperlinks to
   classes from dependencies A, B, C, D, etc.

For projects deployed to [Maven Central], one solution is [javadoc.io], which
offers on-demand browsing of any project that publishes javadoc classifier
artifacts as described above. Links to javadoc.io-hosted javadoc
(e.g. [SciJava Common v2.87.1]) can be passed to the `javadoc` tool as links,
and the javadoc for your library L will then have hyperlinks to the classes
of dependencies A, B, C, D, etc., for which javadoc.io links were provided.

There are still challenges, however:

* For each link given to the `javadoc` tool, its `element-list` (`package-list`
  in older versions of Java) index must be fetched. Unfortunately, this step is
  slow, scaling linearly by the number of links given. For projects with many
  dependencies, each with its own javadoc.io link, this can bloat javadoc
  generation time by many minutes. In an empirical test, building javadoc for a
  small project with no links took 11 seconds, with 37 links took 48 seconds,
  and with 231 links took 215 seconds.

* The javadoc.io service does not support javadoc artifacts published to Maven
  repositories other than Maven Central. So projects published to
  maven.scijava.org, for example, cannot be browsed there. And as far as I
  know, the server-side javadoc.io code is not open source, so configuring
  javadoc.scijava.org to work analogously, but for maven.scijava.org instead of
  Maven Central, requires coding our own solution (i.e., this repository).

## How this repository helps

The `wrangle.py` script generates a **combined javadoc target for a BOM**,
unioning the `element-list`/`package-list` index so that it can be passed to
the `javadoc` tool as a single link target, resulting in fast javadoc build
times, with permanent reproducible links embedded in the resultant javadoc.

The script also unpacks the **actual javadoc for each managed component**.

The combined javadoc target, rather than recapitulating the HTML for every
class of every component, instead uses 301 redirects via an Apache `.htaccess`
file, which point at the unmodified unpacked javadoc for that component.

This approach has several advantages:

* The `javadoc` tool has a single reproducible link target, so new javadoc
  builds more quickly, with classes from dependencies linked with permalinks.

* Every available javadoc for every component managed by every version of
  pom-scijava is accessible from a canonical location, with stable links.

* Old javadoc using version-agnostic (and therefore irreproducible) links
  is adjusted during unpacking to use stable links instead&mdash;e.g.,
  `/SciJava/org/scijava/Context.html` &rarr;
  `/org.scijava/pom-scijava/30.0.0/org/scijava/Context.html` which then
  redirects to `org.scijava/scijava-common/2.85.0/org/scijava/Context.html`.

  The various version-agnostic prefixes from the prior incarnation of the
  javadoc.scijava.org website now redirect to the latest pom-scijava javadoc
  prefix&mdash;e.g., `/SciJava/` &rarr; `/org.scijava/pom-scijava/latest/`
  &rarr; `org.scijava/pom-scijava/31.1.0`, with the `latest` path updating
  over time to always redirect to the newest BOM version hosted on the site.

------------------------------------------------------------------------

[Bill of Materials]:      https://imagej.net/BOM
[IDEs]:                   https://en.wikipedia.org/wiki/Integrated_Development_Environment
[javadoc.io]:             https://javadoc.io/
[javadoc]:                https://en.wikipedia.org/wiki/Javadoc
[`javadoc` tool]:         https://openjdk.java.net/groups/compiler/javadoc-architecture.html
[Maven Central]:          https://search.maven.org/
[SciJava Common v2.87.1]: https://javadoc.io/doc/org.scijava/scijava-common/2.87.1/
