#!/usr/bin/env python3
"""Audit pinned upstream trees; this does not execute benchmark programs.

  python3 scripts/benchmark-inventory.py --source ID=DIR ... --write
  python3 scripts/benchmark-inventory.py --source ID=DIR ... --check

Source checkout paths are supplied by the caller and never stored in the
inventory. Discovery includes inactive workloads and undeployed executables.
Classification is a static porting schedule, not a correctness claim.
"""
import argparse
import collections
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUITE = ROOT / "examples/benchmarks"
FIELDS = ["source", "path", "name", "rune_name", "milestone", "disposition",
          "family", "related", "authors", "sha256", "members", "inputs", "notices", "evidence", "reason"]
EXTENSIONS = {".sml", ".sig", ".mlb", ".cm", ".hs", ".lhs", ".ml", ".mli", ".c", ".h"}
MLKIT_WORKLOADS = set("DLXSimulator PermuteList FuhMishra boyer checksum count-graphs fft fxp life longlife matrix-multiply mpuz msort msortrun peek perm perm1 professor professor2 professor_game psdes-random pseudokit ratio-regions raytrace smith-normal-form stringconcat tailfib tak tsp tyan vector-concat vector-rev wc-input1 wc-scanStream weeks4 zern kkb36c kkb36d kkb_eq klife_eq tststrcmp".split())
MLKIT_DEV_WORKLOADS = set("fib fib0 hanoi life listsort professor_game professor_game_debug rev many_refs".split())
# M2 source review: project members and entrypoint-only aliases.
MLKIT_REVIEW = {
    "test/kitfib35_mlton.sml": ("duplicate", "same n<1 Fibonacci kernel and argument 35 as test/kitfib35.sml; only top-level driver wrapping differs; share the kitfib35 implementation and preserve both source paths"),
    "test/kitfib35_smlnj.sml": ("duplicate", "same n<1 Fibonacci kernel and argument 35 as test/kitfib35.sml; only callable driver wrapping differs; share the kitfib35 implementation and preserve both source paths"),
    "test/kittmergesort_smlnj.sml": ("duplicate", "same copying mergesort, generator, seed and 100000-element input as test/kittmergesort.sml; the sole diff is val result versus fun doit(); the ten-repetition _tp variant remains separate"),
    "test/FuhMishra.sml": ("duplicate", "same application source loaded by FuhMishra.mlb with required lib.sml; retain the project entrypoint and this provenance rather than compiling the incomplete source alone"),
    "test/msort.sml": ("exclude", "support module defining msort; msort.mlb supplies upto.sml and msortrun.sml for the actual invocation"),
    "test/msortrun.sml": ("duplicate", "same invocation msort(upto(50000)) loaded by msort.mlb; retain the complete ordered project and this driver provenance"),
    "test/perm.mlb": ("exclude", "type-inference project containing only declarations from perm1.sml and perm.sml; no computation or timed invocation"),
    "test/perm.sml": ("exclude", "declarations for the perm.mlb type-inference case; prj/findSome are never invoked, not a benchmark workload"),
    "test/perm1.sml": ("exclude", "composePartial helper declaration for perm.mlb, without a workload invocation"),
    "test/stringconcat.sml": ("exclude", "argument-transformation regression: concatenates two literal strings once and prints Hello world; its source comment explicitly checks -no_opt compiler behavior"),
    "test/tststrcmp.sml": ("exclude", "enumerated string-comparison correctness checks with expected booleans and numbered ok reports, not a repeated benchmark workload"),
}
# These pairs were reviewed at the pinned revision. Their complete bodies and
# hardcoded parameters agree; only the top-level invocation/export differs.
MLKIT_ENTRYPOINT_ALIASES = {
    "DLXSimulator_smlnj": "DLXSimulator", "checksum_smlnj": "checksum",
    "matrix-multiply_smlnj": "matrix-multiply", "mpuz_smlnj": "mpuz",
    "peek_smlnj": "peek", "psdes-random_smlnj": "psdes-random",
    "ratio-regions_smlnj": "ratio-regions", "raytrace_smlnj": "raytrace",
    "smith-normal-form_smlnj": "smith-normal-form", "tailfib_smlnj": "tailfib",
    "tak_smlnj": "tak", "tsp_smlnj": "tsp", "tyan_smlnj": "tyan",
    "wc-input1_smlnj": "wc-input1", "wc-scanStream_smlnj": "wc-scanStream",
    "zern_smlnj": "zern", "kitsimple_smlnj": "kitsimple",
    "kitlife35u_mlton": "kitlife35u_smlnj",
}
SANDMARK_PACKAGES = {"alt-ergo", "coq", "cpdf", "cubicle", "decompress", "frama-c", "irmin", "menhir", "owl", "soli", "thread-lwt", "yojson"}


def table(path):
    with path.open(newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        if path.name == "inventory.tsv" and reader.fieldnames != FIELDS:
            raise ValueError("wrong inventory columns")
        rows = list(reader)
        if any(None in row or any(value is None for value in row.values()) for row in rows):
            raise ValueError("malformed table row in " + str(path))
        return rows


def source_files(root, path):
    p = root / path
    if p.is_dir():
        return sorted(q for q in p.rglob("*") if q.is_file() and q.suffix in EXTENSIONS)
    files = [p] if p.exists() else []
    if p.suffix in {".hs", ".lhs"} and p.exists():
        # Multi-entrypoint directories have one inventory key per executable,
        # but each key still needs its transitive local modules. A Main.hs
        # record alone loses the actual application and its feature/notices.
        pending = [p]
        while pending:
            member = pending.pop()
            for module in re.findall(r"^\s*import\s+(?:qualified\s+)?([A-Z][\w.]*)", haskell_code(member), re.M):
                relative = Path(*module.split("."))
                for base in (p.parent, root / "common"):
                    candidates = [base / relative.with_suffix(ext) for ext in (".hs", ".lhs")]
                    dependency = next((candidate for candidate in candidates if candidate.is_file()), None)
                    if dependency is not None:
                        if dependency not in files:
                            files.append(dependency)
                            pending.append(dependency)
                        break
    if p.suffix == ".mlb" and p.exists():
        # Local source members, including directories referenced by projects.
        for word in re.findall(r"[\w./-]+\.(?:sml|sig|mlb)", p.read_text(errors="replace")):
            member = p.parent / word
            if member.is_file() and member not in files:
                files.append(member)
    return sorted(files)


def code_only(text, language="ml"):
    """Remove nested ML/Haskell comments and strings before feature searches."""
    out, pos, comments, string = [], 0, [], False
    pairs = {"{-": "-}"} if language == "haskell" else {"(*": "*)", "/*": "*/"}
    while pos < len(text):
        two = text[pos:pos + 2]
        if comments:
            if two in pairs:
                comments.append(pairs[two]); pos += 2
            elif two == comments[-1]:
                comments.pop(); pos += 2
            else:
                out.append("\n" if text[pos] == "\n" else " "); pos += 1
        elif string:
            if text[pos] == "\\":
                pos += 2
            elif text[pos] == '"':
                string = False; pos += 1
            else:
                out.append("\n" if text[pos] == "\n" else " "); pos += 1
        elif two in pairs:
            comments.append(pairs[two]); out.append(" "); pos += 2
        elif two == "--" and language == "haskell":
            end = text.find("\n", pos)
            pos = len(text) if end == -1 else end
        elif text[pos] == '"':
            string = True; out.append(" "); pos += 1
        else:
            out.append(text[pos]); pos += 1
    return "".join(out)


def mlkit_entrypoint_body(path):
    """Retain strings and every algorithm byte; remove only reviewed adapters."""
    text = path.read_text(encoding="latin-1")
    text = text.removeprefix("(* Added val _ = Main.doit() at end of file -- mael 2001-10-19 *)\n")
    if path.stem in {"kitlife35u_mlton", "kitlife35u_smlnj"}:
        text = re.sub(r'\s*(?:val _ = \(testit \(\); testit \(\); testit \(\)\))?\s*in\s*val done = "done";\s*(?:fun doit\(\) = \(testit\(\); testit\(\); testit\(\)\))?\s*end\s*$', "", text)
    if path.stem == "kitsimple_smlnj":
        text = re.sub(r"structure Main\s*=\s*struct\s*val doit = doit\s*end\s*$", "", text)
    return re.sub(r"\s*(?:val\s+_\s*=\s*(?:Main\.)?doit\s*\(\s*\)\s*;?|fun\s+doit\s*\(\s*\)\s*=\s*Main\.doit\s*\(\s*\))\s*$", "", text).strip()


def digest(root, files):
    h = hashlib.sha256()
    for p in files:
        h.update(str(p.relative_to(root)).encode() + b"\0")
        h.update(p.read_bytes())
        h.update(b"\0")
    return h.hexdigest()


def haskell_code(path):
    text = path.read_text(errors="replace")
    if path.suffix == ".lhs":
        blocks = re.findall(r"\\begin\{code\}(.*?)\\end\{code\}", text, re.S)
        if blocks:
            text = "\n".join(blocks)
        else:
            text = "\n".join(re.findall(r"^[ \t]*> ?(.*)$", text, re.M))
    return code_only(text, "haskell")


def sexps(text):
    text = re.sub(r";;[^\n]*", "", text)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[()]|[^\s()]+', text)
    stack, result = [], []
    for token in tokens:
        if token == "(":
            item = []
            (stack[-1] if stack else result).append(item)
            stack.append(item)
        elif token == ")":
            if not stack:
                raise ValueError("unbalanced Dune form")
            stack.pop()
        else:
            (stack[-1] if stack else result).append(token.strip('"'))
    if stack:
        raise ValueError("unbalanced Dune form")
    return result


def walk_forms(items):
    for item in items:
        if isinstance(item, list):
            yield item
            yield from walk_forms(item)


def discover(source, root):
    found = {}

    def add(path, name, evidence):
        if path not in found:
            found[path] = {"path": path, "name": name, "evidence": []}
        found[path]["evidence"].append(evidence)

    if source == "mlton":
        for p in sorted((root / "benchmark/tests").glob("*.sml")):
            add(str(p.relative_to(root)), p.stem, "benchmark/tests/Makefile")
    elif source == "smlnj":
        for p in sorted((root / "programs").iterdir()):
            if p.is_dir():
                add(str(p.relative_to(root)), p.name, "README.md;programs/*/sources.cm")
        for name in re.findall(r"\[`([^`]+)`\]\(programs/", (root / "README.md").read_text()):
            add("programs/" + name, name, "README.md")
    elif source == "mlkit":
        for folder in ("test", "test_dev"):
            for p in sorted((root / folder).iterdir()):
                if p.is_file() and p.suffix in {".sml", ".mlb"}:
                    add(str(p.relative_to(root)), p.stem, "test/all.tst;test_dev/Makefile")
    elif source == "nofib":
        for category in ("imaginary", "spectral", "real", "gc", "shootout", "parallel", "smp"):
            for p in sorted((root / category).rglob("Makefile")):
                if p.parent != root / category:
                    entries = [q for q in p.parent.iterdir() if q.suffix in {".hs", ".lhs"} and q.is_file()
                               and re.search(r"^[ \t]*(?:module[ \t]+Main\b|main[ \t]*(?:::|=))", haskell_code(q), re.M)]
                    if len(entries) > 1:
                        for entry in sorted(entries):
                            add(str(entry.relative_to(root)), entry.stem, str(p.relative_to(root)))
                    else:
                        add(str(p.parent.relative_to(root)), p.parent.name, str(p.relative_to(root)))
    elif source == "sandmark":
        for p in sorted((root / "benchmarks").rglob("*")):
            if not p.is_file() or not (p.name == "dune" or p.name.endswith("-dune.inc")):
                continue
            for form in walk_forms(sexps(p.read_text())):
                if form and form[0] in ("executable", "executables"):
                    for entry in form[1:]:
                        if isinstance(entry, list) and entry and entry[0] in ("name", "names"):
                            for name in entry[1:]:
                                if isinstance(name, str):
                                    add(str(p.parent.relative_to(root) / (name + ".exe")), name, str(p.relative_to(root)))
        for p in sorted(root.glob("*.json")):
            data = json.loads(p.read_text())
            if not isinstance(data, dict):
                continue
            for bench in data.get("benchmarks", []):
                executable = re.sub(r"\.(?:bc|exe)$", ".exe", bench["executable"])
                add(executable, re.sub(r"\.bc$", "", bench["name"]), p.name)
                # Prefer the upstream runplan's logical name to a generic
                # executable name such as "main" or "kernel1_run".
                if p.name == "run_config.json":
                    found[executable]["name"] = re.sub(r"\.bc$", "", bench["name"])
    else:
        raise ValueError("unknown source " + source)
    return list(found.values())


def family(name, text):
    key = name.lower()
    if any(x in key for x in ("fft", "nbody", "n-body", "barnes", "mandel", "nucleic", "ray", "simple", "fem", "fluid", "almabench", "matrix", "grammatrix", "decomposition", "durand", "levinson", "minilight", "sphere", "zern", "arith")):
        return "numerical"
    if any(x in key for x in ("sort", "merge", "list", "rev", "sieve", "primes", "hamming", "wheel")):
        return "lists-streams"
    if any(x in key for x in ("lex", "yacc", "parser", "infer", "hamlet", "typecheck", "prolog", "veritas", "anna", "vliw")):
        return "compiler-application"
    if any(x in key for x in ("boyer", "bdd", "zdd", "logic", "knuth", "kb", "rewrite", "claus", "crypt", "sat", "queens", "tsp", "minimax")):
        return "symbolic-search"
    if any(x in key for x in ("fib", "tak", "ack", "motzkin", "sudan", "evenodd")):
        return "calls-recursion"
    if any(x in key for x in ("gc", "alloc", "tree", "dangle", "reynolds", "space", "mutstore", "weak", "final", "roots", "stress")):
        return "allocation-lifetimes"
    if any(x in key for x in ("integer", "pidigits", "bernou", "digits", "rsa", "smith", "zarith", "paraffin")) or re.search(r"\b(?:IntInf|Integer)\b", text):
        return "integer-arithmetic"
    return "application" if len(text) > 16000 else "kernel"


def classify(source, root, item, files, text):
    path, name = item["path"], item["name"]
    milestone = {"mlton": "M2", "smlnj": "M2", "mlkit": "M2", "nofib": "M3", "sandmark": "M5"}[source]
    reason = "portable workload; retain algorithm and review driver, numeric assumptions, fixtures and notices before import"
    disposition = "import"
    if source == "mlkit":
        stem = re.sub(r"_(smlnj|mlton|tp|no_basislib)$", "", name)
        candidate = stem.startswith("kit") or stem in MLKIT_WORKLOADS or (path.startswith("test_dev/") and stem in MLKIT_DEV_WORKLOADS)
        if not candidate:
            disposition, milestone, reason = "exclude", "-", "regression or support source outside the benchmark families; test/all.tst and test_dev/Makefile distinguish compiler/Basis tests"
        region_names = set(re.findall(r"\b(?:resetRegions|forceResetting)\b", text))
        noops = set(re.findall(r"\bfun\s+(resetRegions|forceResetting)\s+_\s*=\s*\(\s*\)", text))
        if disposition == "import" and region_names:
            if region_names <= noops:
                reason = "portable upstream variant defines region-control functions as no-ops; preserve this distinct storage policy and its original algorithm"
            else:
                disposition, reason = "defer", "calls ML Kit region-reset controls; removing these changes the measured storage policy; reconsider with equivalent region lifetime controls, and retain portable algorithm variants separately"
        if path in MLKIT_REVIEW:
            disposition, reason = MLKIT_REVIEW[path]
            if disposition == "exclude": milestone = "-"
        if path.startswith("test/") and name in MLKIT_ENTRYPOINT_ALIASES:
            canonical = root / "test" / (MLKIT_ENTRYPOINT_ALIASES[name] + ".sml")
            if canonical.is_file() and mlkit_entrypoint_body(root / path) == mlkit_entrypoint_body(canonical):
                disposition, reason = "duplicate", "same complete kernel and hardcoded parameters as " + str(canonical.relative_to(root)) + "; only the reviewed top-level invocation/export adapter differs; share that implementation and retain both provenance paths"
        if path == "test_dev/kitsimple.sml":
            disposition, reason = "duplicate", "identical source and hardcoded workload to mlkit:test/kitsimple.sml; retain the test entry and both provenance paths"
    if source == "smlnj":
        if name in {"BASIS", "common"}:
            disposition, milestone, reason = "exclude", "-", "shared library/benchmark interface, not an independent workload"
        elif name in {"barnes-hut", "delta-blue", "dlx", "kcfa", "pia", "regex"}:
            disposition, reason = "defer", "upstream README marks this variant broken; repair and establish an independent result before import"
        elif name in {"cml-sieve", "pingpong"}:
            disposition, reason = "defer", "requires Concurrent ML message passing; reconsider when a compatible concurrency facility exists"
    if source == "nofib":
        makefile = (root / path).parent / "Makefile"
        excluded = set()
        if (root / path).is_file() and makefile.is_file():
            for value in re.findall(r"^EXCLUDED_SRCS\s*[:?+]?=\s*(.*)$", makefile.read_text(errors="replace"), re.M):
                excluded.update(value.split())
        direct = [p for p in files if p.parent == root / path or p == root / path]
        if Path(path).name in excluded:
            disposition, milestone, reason = "exclude", "-", "upstream Makefile lists this test entrypoint in EXCLUDED_SRCS; retain the application entrypoint and record this support/correctness program separately"
        elif not any(re.search(r"^[ \t]*(?:module[ \t]+Main\b|main[ \t]*(?:::|=))", haskell_code(p), re.M) for p in direct if p.suffix in {".hs", ".lhs"}):
            disposition, milestone, reason = "exclude", "-", "aggregate, support directory, or old source fragment without a standalone Main entrypoint"
        elif path.startswith(("parallel/", "smp/")):
            disposition, reason = "defer", "parallel/concurrent/STM collection; preserve its runtime model and reconsider with the corresponding Rune facilities"
        elif path.startswith("real/"):
            milestone = "M4"
        if disposition == "import" and re.search(r"^[ \t]*(?:foreign import|import\s+(?:qualified\s+)?(?:GHC\.Prim|GHC\.Conc|Control\.Concurrent|Control\.Parallel|System\.Mem\.Weak))", text, re.M):
            disposition, reason = "defer", "source imports runtime-specific primitives, concurrency, or weak references; audit a faithful portable replacement before reconsideration"
        excluded_helpers = {"gc/fulsom/Bah.hs", "real/fulsom/Bah.hs", "real/infer/TestTerm.hs", "real/infer/TestType.hs", "real/compress/BinTest.hs", "real/compress/Lzw.hs", "real/compress/Lzw2.hs", "real/compress/Uncompress.hs"}
        if path in excluded_helpers:
            disposition, milestone, reason = "exclude", "-", "auxiliary test or alternate entrypoint; the directory Makefile excludes it or selects the Main driver, not a separate benchmark invocation"
        if path in {"gc/fulsom/Main.hs", "real/fulsom/Main.hs", "real/compress/Main.hs", "real/infer/Main.hs"}:
            item["name"] = path.split("/")[-2]
    if source == "sandmark":
        group = path.split("/")[1] if path.startswith("benchmarks/") else "external"
        if group in SANDMARK_PACKAGES or group == "external":
            disposition, reason = "defer", "requires the upstream application/package dependency graph (" + group + "); reconsider with a portable implementation of those dependencies"
        elif re.search(r"\b(?:effect\s+[A-Z]|Effect\.(?:Deep|Shallow|perform)|perform\s+|Domain\.(?:spawn|join)|Domainslib|Thread\.|Lwt[._]|Weak\.|Ephemeron\.|Gc\.(?:finalise|full_major|major|minor|compact|major_slice)|Gc\.get|Gc\.set|Obj\.|Ms_sched\.|external\s+\w+\s*:|Unix\.(?:fork|wait|create_process)|foreign_stubs|[Oo]camlcapi)", text):
            disposition, reason = "defer", "source uses OCaml-specific effects, concurrency, GC/weak-reference introspection, unsafe objects or C bindings; reconsider with equivalent runtime facilities"
        elif "multicore" in name or "parallel" in name or "multiprocess" in name or group in {"mpl", "multicore-gcroots", "multicore-structures", "multicore-grammatrix"}:
            disposition, reason = "defer", "parallel/runtime-specific executable; retain its original execution model"
    if source == "mlton" and name == "tak":
        milestone = "M1"
    if source == "mlkit" and path == "test/kittmergesort.sml":
        milestone = "M1"
    if source == "nofib" and path == "imaginary/primes":
        milestone = "M1"
    if source == "sandmark" and path == "benchmarks/bdd/bdd.exe":
        milestone = "M1"
    return milestone, disposition, reason


def build(source, root, lock):
    rows = []
    for item in discover(source, root):
        path, name = item["path"], item["name"]
        dependency_forms = []
        if source == "sandmark":
            p = root / path
            own = p.with_suffix(".ml")
            files = [own] if own.is_file() else (source_files(root, str(p.parent.relative_to(root))) if path.startswith("benchmarks/") else [])
            if path.startswith("benchmarks/") and p.parent.exists():
                metadata = [q for q in p.parent.iterdir() if q.is_file() and (q.name == "dune" or q.name.endswith("-dune.inc"))]
                files += metadata
                for meta in metadata:
                    for form in walk_forms(sexps(meta.read_text())):
                        if form and form[0] in {"executable", "executables"} and any(isinstance(entry, list) and entry and entry[0] in {"name", "names"} and p.stem in entry[1:] for entry in form[1:]):
                            dependency_forms.append(str(form))
                            mains = [name for entry in form[1:] if isinstance(entry, list) and entry and entry[0] in {"name", "names"} for name in entry[1:]]
                            for entry in form[1:]:
                                if isinstance(entry, list) and entry and entry[0] == "modules":
                                    for module in entry[1:]:
                                        if isinstance(module, str) and (module not in mains or module == p.stem):
                                            member = p.parent / (module + ".ml")
                                            if member.is_file():
                                                files.append(member)
        else:
            files = source_files(root, path)
        files = sorted(set(files))
        text = "\n".join(p.read_text(errors="replace") for p in files if p.suffix in EXTENSIONS and p.suffix not in {".cm", ".mlb"})
        code = "\n".join(haskell_code(p) for p in files if p.suffix in {".hs", ".lhs"}) if source == "nofib" else code_only(text)
        milestone, disposition, reason = classify(source, root, item, files, code + "\n" + "\n".join(dependency_forms))
        name = item["name"]
        parent = (root / path) if (root / path).is_dir() else (root / path).parent
        inputs = set()
        if files and parent.exists() and path.startswith(("programs/", "benchmarks/", "imaginary/", "spectral/", "real/", "gc/", "shootout/", "parallel/", "smp/")):
            for fixture in parent.rglob("*"):
                if fixture.is_file() and (fixture.name == "ANSWER" or fixture.suffix in {".stdin", ".stdout", ".faststdin", ".faststdout", ".slowstdin", ".slowstdout", ".expected", ".out", ".ok"} or "DATA" in fixture.relative_to(parent).parts):
                    inputs.add(str(fixture.relative_to(root)))
        for ref in re.findall(r'"([^"\n]+)"', text):
            if not re.fullmatch(r"[\w./@+ -]{1,240}", ref):
                continue
            candidate = (parent / ref).resolve()
            if candidate.is_relative_to(root) and candidate.is_file():
                inputs.add(str(candidate.relative_to(root)))
        notices = lock["notices"].split(";") if lock["notices"] not in {"", "-"} else []
        if files and parent.exists() and ((root / path).is_dir() or source == "nofib" or (source == "sandmark" and path.startswith("benchmarks/"))):
            for notice in parent.rglob("*"):
                if notice.is_file() and re.fullmatch(r"(?:LICENSE|COPYING|COPYRIGHT)(?:\.[\w-]+)?", notice.name, re.I):
                    notices.append(str(notice.relative_to(root)))
        authors = set()
        context = [p for p in parent.iterdir() if p.is_file() and p.name in {"README", "README.md", "Makefile", "FILES", "sources.cm"}] if parent.exists() and files else []
        item["evidence"].extend(str(p.relative_to(root)) for p in context)
        for p in files + context:
            header = p.read_text(errors="replace")[:8000]
            if re.search(r"[Cc]opyright|[Ll]icen[sc]e|[Ww]ritten by|[Aa]uthor:|[Tt]ranslated", header):
                notices.append(str(p.relative_to(root)) + ":header")
            for attribution in re.finditer(r"(?:[Ww]ritten|[Tt]ranslated|[Pp]orted|[Cc]ontributed)(?: to [^\n]*?)? by ([^\n]+)|[Aa]uthors?: ([^\n]+)", header):
                author = (attribution.group(1) or attribution.group(2)).strip(" *()-")
                if len(author) <= 180:
                    authors.add(author)
        if source == "sandmark" and not path.startswith("benchmarks/"):
            notices = ["dependencies/template/*.opam (package sources and notices)"]
        rows.append(dict(source=source, path=path, name=name, rune_name=name,
                         milestone=milestone, disposition=disposition,
                         family=family(name, text), related="", authors=";".join(sorted(authors)) or "not stated in scanned source headers",
                         sha256=digest(root, files),
                         members=";".join(str(p.relative_to(root)) for p in files),
                         inputs=";".join(sorted(inputs)), notices=";".join(sorted(set(notices))),
                         evidence=";".join(sorted(set(item["evidence"]))), reason=reason))
    return rows


def related(rows):
    aliases = {"nucleic": "pseudoknot", "nucleic2": "pseudoknot", "DLXSimulator": "dlx", "smith-nf": "smith-normal-form", "kb": "knuth-bendix"}
    groups = collections.defaultdict(list)
    for row in rows:
        base = re.sub(r"_(smlnj|mlton|tp|no_basislib)$", "", row["name"])
        groups[aliases.get(base, base)].append(row)
    for group in groups.values():
        for row in group:
            row["related"] = ";".join(other["source"] + ":" + other["path"] for other in group if other is not row)


def validate(rows, locks):
    seen = set()
    for row in rows:
        key = row["source"], row["path"]
        if key in seen or row["source"] not in locks:
            raise ValueError("duplicate or unknown inventory key " + str(key))
        seen.add(key)
        if row["disposition"] not in {"import", "duplicate", "defer", "exclude"}:
            raise ValueError("bad disposition " + str(key))
        if not row["reason"] or not row["evidence"] or not row["rune_name"]:
            raise ValueError("missing audit metadata " + str(key))
        if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
            raise ValueError("bad source digest " + str(key))
    names = [r["rune_name"] for r in rows if r["disposition"] == "import"]
    if len(names) != len(set(names)):
        raise ValueError("colliding proposed import names")
    for source, lock in locks.items():
        if "entries" in lock:
            count = sum(row["source"] == source for row in rows)
            if count != int(lock["entries"]):
                raise ValueError("incomplete source inventory for " + source + ": " + str(count))


def names(rows):
    # Reserve classic SML names first, while keeping distinct source variants.
    used = set()
    for row in sorted(rows, key=lambda r: (list(("mlton", "smlnj", "mlkit", "nofib", "sandmark")).index(r["source"]), r["path"])):
        name = row["name"]
        if row["disposition"] != "import":
            continue
        if name in used:
            name += "-" + row["source"]
        if name in used:
            parts = row["path"].split("/")
            qualifier = "-".join(parts[1:-1]) if row["source"] == "sandmark" else "-".join(parts[:-1])
            name += "-" + qualifier
        if name in used:
            raise ValueError("cannot disambiguate " + row["path"])
        row["rune_name"] = name
        used.add(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", default=[], metavar="ID=DIR")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    locks = {row["source"]: row for row in table(SUITE / "upstreams.tsv")}
    supplied = dict(value.split("=", 1) for value in args.source)
    if supplied and set(supplied) != set(locks):
        parser.error("supply all five pinned source trees")
    if args.write and not supplied:
        parser.error("--write requires all pinned sources")
    if supplied:
        rows = []
        for source in locks:
            root = Path(supplied[source]).resolve()
            revision = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            if revision != locks[source]["revision"]:
                raise ValueError("wrong revision for " + source + ": " + revision)
            if subprocess.check_output(["git", "-C", str(root), "status", "--porcelain", "--untracked-files=normal"], text=True).strip():
                raise ValueError("modified or untracked upstream sources: " + source)
            rows.extend(build(source, root, locks[source]))
        names(rows)
        rows.sort(key=lambda r: (r["source"], r["path"]))
        related(rows)
    else:
        rows = table(SUITE / "inventory.tsv")
    validate(rows, locks)
    if args.write:
        with (SUITE / "inventory.tsv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    elif supplied and rows != table(SUITE / "inventory.tsv"):
        raise ValueError("inventory differs from pinned discovery/classification; review before --write")
    for source in locks:
        counts = collections.Counter(r["disposition"] for r in rows if r["source"] == source)
        print(source + ": " + ", ".join(str(counts[k]) + " " + k for k in sorted(counts)))
    print("inventory: OK (" + str(len(rows)) + " entries)")


if __name__ == "__main__":
    main()
