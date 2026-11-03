[![check](https://github.com/scijava/javadoc.scijava.org/actions/workflows/check.yml/badge.svg)](https://github.com/scijava/javadoc.scijava.org/actions/workflows/check.yml)

This repository holds the hand-made parts of
[https://javadoc.scijava.org/](https://javadoc.scijava.org/): the front page,
its stylesheet and its icons. It also documents how the rest of the site, the
javadoc itself, is generated: by [pombast], from the components managed by
[pom-scijava].

To contribute, please:

1. [fork](https://github.com/scijava/javadoc.scijava.org/fork) the project,
2. make your changes, commit and push,
3. [open a Pull Request](https://help.github.com/articles/creating-a-pull-request/).

## What the site serves

1. **Javadoc for each component**, at a versioned path.
   E.g. `/org.scijava/scijava-common/2.100.1/`. Analogous to [javadoc.io],
   but also covering artifacts deployed to maven.scijava.org, and prepared in
   advance rather than on demand.

2. **A unioned index of all components managed by a BOM**, per BOM release.
   E.g. `/org.scijava/pom-scijava/45.1.0/`. Useful as a single link target for
   the `javadoc` tool, or for browsing the libraries of one BOM version. The
   union holds no class pages of its own: each one 301-redirects to the
   component that owns it. For example:
   ```
   /org.scijava/pom-scijava/45.1.0/net/imglib2/img/Img.html
   ```
   redirects to:
   ```
   /net.imglib2/imglib2/8.0.0/net/imglib2/img/Img.html
   ```
   since the `net.imglib2.img.Img` class is part of `net.imglib2:imglib2:8.0.0`,
   the version pom-scijava 45.1.0 manages.

3. **Named unions over parts of a BOM**, e.g. all of ImgLib2's components:
   `/org.scijava/pom-scijava/45.1.0/net.imglib2/`. Each works like the full
   union, with its own index and landing page.

4. **`latest` aliases**, which float to the newest release on the site:
   `/net.imagej/ij/latest/` → `/net.imagej/ij/1.54p/`, and
   `/org.scijava/pom-scijava/latest/…` → the newest pom-scijava. These are 302
   (temporary) redirects, so browsers never cache a stale target. A page the
   newest union no longer has (e.g. a class since removed) is sent to the
   newest older union that does, instead of a 404.

5. **The front page**, from this repository.

The site also keeps old links working. Its earlier incarnation served
unversioned trees such as `/ImageJ2/`, `/SciJava/` and `/ImgLib2/`; their
front pages now redirect to the project's named union, or else its main
component (e.g. `/ImgLib2/` → `/org.scijava/pom-scijava/latest/net.imglib2/`),
and their class pages to the same class via a union (e.g. `/ImgLib2/net/imglib2/img/Img.html` →
`/org.scijava/pom-scijava/latest/net.imglib2/net/imglib2/img/Img.html`).
`/Java{N}/` serves the Java SE API docs: for the LTS versions (8, 11, 17, 21
and 25), generated from OpenJDK's own sources; for others, and for JavaFX at
`/JavaFX{N}/`, proxied from the official docs. Projects whose javadoc lives
elsewhere redirect there.

The site hosts javadoc of many projects it does not author, so that the
components managed by pom-scijava can link to it. These copies are not the
projects' official documentation, and say so in a banner on every page; they
are also kept out of search engines (`X-Robots-Tag: noindex`), so that a
search never presents them as a project's current documentation. This covers
every project outside the SciJava family, and the JDK docs generated here.

## Background and rationale

The site is designed around the idea of a [Bill of Materials] (BOM), which
provides a list of *managed* components at particular versions that are
tested and working together. By importing the BOM into your build, you can
then depend on any combination of the managed components without explicitly
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
  Maven Central, requires coding our own solution.

That solution is [pombast]'s `javadoc` command. Its BOM union gives the
`javadoc` tool a single, fast link target, so builds stay quick and embed
permanent, reproducible links. Every available javadoc of every component
managed by every pom-scijava release on the site sits at a canonical,
versioned location.

## How the javadoc is made

For each release of the BOM, `pombast javadoc`:

* **Resolves** every managed component's full dependency closure, as Maven
  would, so the components it depends on are included too.

* **Unpacks** each component's `-javadoc` JAR into `/{groupId}/{artifactId}/{version}/`.
  Where none is published, or it is an empty stub (as some projects publish to
  satisfy Maven Central's rules), it **generates** the javadoc from the
  component's `-sources` JAR instead, as leniently as the `javadoc` tool
  allows.

* **Cross-links** each component's javadoc against the versions *it* actually
  depends on, not the versions the BOM manages, so a component's pages are
  the same whichever BOM brought it in. Old javadoc that linked to the
  unversioned trees (e.g. `/SciJava/org/scijava/Context.html`) is rewritten to
  link to the exact versioned page instead, class names that were never linked
  become links, and JDK links point at the component's target Java version
  under `/Java{N}/`.

* **Builds the unions** for that BOM release, and regenerates the site-wide
  redirect maps (union paths, `latest` versions, and `latest` fallbacks) from
  everything on disk.

Component javadoc is cached per version, so each new BOM release only adds
the component versions it introduces. pombast keeps its load on Maven
repositories low: requests are spaced out, misses (e.g. a component that
publishes no `-javadoc` JAR) are remembered rather than retried each run,
and a run stops at the first refusal from a repository. Each run reports
how many requests it made.

## Where everything lives

| What | Where |
|------|-------|
| Front page, stylesheet, icons | this repository |
| The generator, and the script that publishes its output | [pombast] (`pombast javadoc`, `bin/publish-javadoc.sh`) |
| What is built: settings and named unions | [pom-scijava]'s `pombast.toml`, `[javadoc]` section |
| Redirect rules (legacy paths, `latest`, unions, proxies), banner | [uw-loci/loci-servers] (private), `apache/sites/javadoc.scijava.org.include` |
| Java SE API docs (`/Java{N}/`) | `.tools/jdk-javadoc.py` |
| Building each new pom-scijava release | `.tools/update.py` |

## Building and publishing

New pom-scijava releases are built and published automatically:
`.tools/update.py` notices each release whose GitHub release workflow has
succeeded, waits until its POM is on Maven Central, then builds it, publishes,
and runs the checks below. It runs hourly as the `cronbot` user, from the
server's cron configuration in [uw-loci/loci-servers] (private:
`cron/refresh-javadoc`, via `bin/refresh-javadoc.sh`), and prints nothing when
there is nothing to do, so cron mails only when it acted or failed. It runs
from its own clones of this repository, pombast and pom-scijava under
`/var/www/javadoc/src`, fast-forwarded before each run, never from anyone's
working copy.

Everything under `/var/www/javadoc` belongs to `cronbot`, so run anything by
hand as that user too. To build a release and publish:

```sh
sudo -u cronbot python3 /var/www/javadoc/src/javadoc.scijava.org/.tools/update.py
```

`update.py` builds every successfully released version not yet on the site.
For other versions, or to rebuild many at once, use `.tools/backfill.sh`
(below), then publish:

```sh
sudo -u cronbot /var/www/javadoc/src/pombast/bin/publish-javadoc.sh \
  -s /var/www/javadoc/src/javadoc.scijava.org \
  /var/www/javadoc/build /var/www/javadoc/releases /var/www/javadoc/current
```

`publish-javadoc.sh` hard-links the build tree into a new, timestamped
snapshot under `/var/www/javadoc/releases/`, lays this repository's files
over it, converts the redirect maps into the format Apache reads, and then
switches the `/var/www/javadoc/current` symlink to it in a single step.
`/var/www/javadoc.scijava.org`, the web server's document root, points at
`current`. Visitors therefore see either the old site or the new one, never a
half-published one. Since the snapshots share unchanged files, each costs
about a gigabyte rather than another copy of the site. The newest three are
kept; to roll back, point `current` at an older one:

```sh
cd /var/www/javadoc
ln -sfn releases/OLDER-STAMP current.new && mv -T current.new current
```

Use `publish-javadoc.sh -n` to see what it would do without doing it.

Everything the site is built from and served from lives under
`/var/www/javadoc/`, on one filesystem (as hard links require):

| Path | What |
|------|------|
| `build/` | the build tree pombast writes; every snapshot shares its unchanged files |
| `logs/` | each release's build log (and `update.py`'s lock file) |
| `releases/` | the published snapshots |
| `current` | the live snapshot; `/var/www/javadoc.scijava.org` points here |
| `src/` | the clones the automation runs from (this repository, pombast, pom-scijava) |
| `cache/` | the build's caches: Maven repository (`m2/`), JDKs (`cjdk/`), Python packages (`uv/`) |

Keep `cache/m2` in particular: besides the downloaded artifacts, it holds
pombast's record of artifacts known to be missing, which spares the Maven
repositories thousands of repeated requests.

To rebuild many releases at once (e.g. after a pombast or jgo fix that changes
what is built), `.tools/backfill.sh VERSION...` builds them one at a time,
stopping at the first sign of trouble with a repository. To try changes to the
Apache rules before reloading production, `.tools/apache-test.sh start` runs
them on a throwaway, unprivileged server over the build tree, at
`http://127.0.0.1:18080`, for `.tests/check.py --base` or
`.tools/apache-test.sh trace PATH...`.

The Java SE API docs are generated from the `src.zip` of each version's Zulu
(OpenJDK) build, with that JDK's own `javadoc` tool, into the build tree:

```sh
cd /var/www/javadoc/src/javadoc.scijava.org
sudo -u cronbot env UV_CACHE_DIR=/var/www/javadoc/cache/uv \
  uv run --project ../pombast python .tools/jdk-javadoc.py -o /var/www/javadoc/build 8 11 17 21 25
```

## Testing

`.tests/check.py` checks the live site's URL behavior, following redirects
while they stay on the site:

* **`contract`**: the expectations in `.tests/contract.txt`, one path per
  line with the status or URL it must end at: versioned pages, unions,
  `latest`, legacy paths, proxies, and external redirects.
* **`legacy`**: the links in `.tests/legacy-urls.txt`, sampled from real
  traffic to the site's old unversioned trees, must each still reach the
  same page.
* **`index`**: every link on the front page, from this checkout's
  `index.html`, so a proposed change is checked before it is published.

```sh
python3 .tests/check.py              # all checks, against javadoc.scijava.org
python3 .tests/check.py index -v     # one check, listing passes too
python3 .tests/check.py --base http://localhost:8080 contract
```

It needs only Python 3. GitHub Actions runs it on every push and pull request.
Since most breakage would come from outside this repository (the server's
configuration, a new publish, or a site we redirect to changing), it also runs
after each automatic publish, and daily on the server (loci-servers'
`cron/check-javadoc`), where `-q` keeps it silent unless something fails, so
cron mails only failures.

## Adding a project to the front page

1. Add a 64×64 icon to `images/`.
2. Add a box to `index.html` linking to the project's `latest` javadoc, e.g.
   `org.example/example/latest/`, or to a named union for a project of many
   components.
3. If the project should get a named union, add it to pom-scijava's
   `[javadoc.unions]`.
4. Publish as above.

------------------------------------------------------------------------

[Bill of Materials]:      https://imagej.net/BOM
[IDEs]:                   https://en.wikipedia.org/wiki/Integrated_Development_Environment
[javadoc.io]:             https://javadoc.io/
[javadoc]:                https://en.wikipedia.org/wiki/Javadoc
[`javadoc` tool]:         https://openjdk.java.net/groups/compiler/javadoc-architecture.html
[Maven Central]:          https://search.maven.org/
[pom-scijava]:            https://github.com/scijava/pom-scijava
[pombast]:                https://github.com/scijava/pombast
[SciJava Common v2.87.1]: https://javadoc.io/doc/org.scijava/scijava-common/2.87.1/
[uw-loci/loci-servers]:   https://github.com/uw-loci/loci-servers
