#!/usr/bin/env python3
"""Check javadoc.scijava.org's URL behavior against the live site.

Three checks, all following redirects while they stay on the site:

* contract.txt -- explicit expectations: each line is a path and either the
  status it must end with, or a glob of the URL it must end at. A glob that
  stays on the site must also end in a 200.
* legacy-urls.txt -- links to the unversioned trees of the site's earlier
  incarnation, sampled from real traffic. Each must reach the same page under
  its new, versioned home (a 200 at a path ending in that page), unless its
  tree now redirects off the site.
* ../index.html -- every link on the front page (this checkout's copy, so a
  proposed change is checked before it is published) must resolve.

Usage: check.py [--base URL] [contract|legacy|index ...]
The base URL defaults to $JDBASE, else https://javadoc.scijava.org.
"""

import argparse
import fnmatch
import http.client
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

HERE = Path(__file__).resolve().parent
MAX_HOPS = 10


class Site:
    def __init__(self, base: str):
        u = urlsplit(base)
        self.base = base.rstrip("/")
        self.host, self.port, self.tls = u.hostname, u.port, u.scheme == "https"

    def follow(self, path: str) -> tuple[int, str, list[int]]:
        """Follow redirects from ``path`` while they stay on the site.

        Returns the last status, the URL it ended at (a site path, or an
        absolute URL once it leaves the site), and the statuses seen.
        """
        statuses = []
        for _ in range(MAX_HOPS):
            cls = http.client.HTTPSConnection if self.tls else http.client.HTTPConnection
            conn = cls(self.host, self.port, timeout=30)
            try:
                conn.request("GET", path, headers={"User-Agent": "javadoc.scijava.org-check"})
                r = conn.getresponse()
                r.read()
            finally:
                conn.close()
            statuses.append(r.status)
            loc = r.getheader("Location")
            if r.status not in (301, 302, 303, 307, 308) or not loc:
                return r.status, path, statuses
            u = urlsplit(urljoin(f"{self.base}{path}", loc))
            if u.hostname != self.host:
                return r.status, u.geturl(), statuses
            path = u.path + (f"?{u.query}" if u.query else "")
        return 0, path, statuses


def lines(name: str):
    for line in (HERE / name).read_text().splitlines():
        line = line.split(" #")[0].strip()
        if line and not line.startswith("#"):
            yield line


def check_contract(site: Site):
    for line in lines("contract.txt"):
        path, expect = line.split()
        status, end, seen = site.follow(path)
        if expect.isdigit():
            ok = status == int(expect) and not end.startswith("http")
        else:
            ok = fnmatch.fnmatchcase(end, expect) and (end.startswith("http") or status == 200)
        yield ok, f"{path} -> {end} {seen} (expected {expect})"


# Rewrites the site applies on purpose, so the landing page differs from the
# requested one: frames and class-use pages modern javadoc lacks, and the
# package rename between the SciJava and JogAmp forks of Java 3D.
_FALLBACKS = ((r"package-(frame|use)\.html$", "package-summary.html"), (r"class-use/", ""))


def _legacy_page(url: str) -> tuple[str, str]:
    """The tree and page a legacy URL asks for ("" for the tree's front page)."""
    path, _, query = url.partition("?")
    tree, _, rel = path.lstrip("/").partition("/")
    query = unquote(query).rstrip("=")
    if rel in ("", "index.html") and "/" in query and query.endswith(".html"):
        rel = query  # an old frameset link: /Tree/index.html?pkg/Class.html
    rel = re.sub("/+", "/", rel).lstrip("/")
    return tree, "" if "/" not in rel else rel  # top-level pages: front page


def _same_page(tree: str, rel: str, end: str) -> bool:
    end = end.partition("?")[0]
    if tree == "Java3D":
        rel = re.sub(r"\borg/scijava/(java3d|vecmath)\b", r"org/jogamp/\1", rel)
    candidates = [rel] + [re.sub(a, b, rel) for a, b in _FALLBACKS]
    return any(end.endswith("/" + c) for c in candidates)


def check_legacy(site: Site):
    urls = list(lines("legacy-urls.txt"))

    def one(url):
        tree, rel = _legacy_page(url)
        status, end, seen = site.follow(url)
        if end.startswith("http"):
            return True, f"{url} -> {end} (off site)"
        ok = status == 200 and (not rel or _same_page(tree, rel, end))
        return ok, f"{url} -> {end} {seen}"

    with ThreadPoolExecutor(8) as pool:
        yield from pool.map(one, urls)


def check_index(site: Site):
    page = (HERE.parent / "index.html").read_text(encoding="utf-8")
    hrefs = sorted(set(re.findall(r'<a href="([^"]+)"', page)))

    def one(href):
        if href.startswith("http"):
            u = urlsplit(href)
            if u.hostname != site.host:
                return True, f"{href} (external, not checked)"
            href = u.path
        path = "/" + href.lstrip("/")
        status, end, seen = site.follow(path)
        ok = status == 200 or end.startswith("http")
        return ok, f"{path} -> {end} {seen}"

    with ThreadPoolExecutor(8) as pool:
        yield from pool.map(one, hrefs)


CHECKS = {"contract": check_contract, "legacy": check_legacy, "index": check_index}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", default=os.environ.get("JDBASE", "https://javadoc.scijava.org"))
    ap.add_argument("-v", "--verbose", action="store_true", help="also list passes")
    ap.add_argument("-q", "--quiet", action="store_true", help="print nothing unless something fails (for cron)")
    ap.add_argument("checks", nargs="*", metavar="CHECK", help=f"any of {', '.join(CHECKS)} (default: all)")
    args = ap.parse_args()
    unknown = set(args.checks) - set(CHECKS)
    if unknown:
        ap.error(f"unknown check(s): {', '.join(sorted(unknown))}")
    site = Site(args.base)
    report = []
    failed = 0
    for name in args.checks or CHECKS:
        results = list(CHECKS[name](site))
        bad = [msg for ok, msg in results if not ok]
        failed += len(bad)
        report.append(f"{name}: {len(results) - len(bad)}/{len(results)} passed")
        report += [f"  {'ok  ' if ok else 'FAIL'} {msg}" for ok, msg in results
                   if not ok or args.verbose]
    if failed or not args.quiet:
        print("\n".join(report))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
