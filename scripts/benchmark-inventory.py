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
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUITE = ROOT / "examples/benchmarks"
FIELDS = ["source", "path", "name", "rune_name", "milestone", "disposition",
          "family", "related", "authors", "sha256", "members", "inputs", "notices", "evidence", "reason"]
EXTENSIONS = {".fun", ".sml", ".sig", ".mlb", ".cm", ".hs", ".lhs", ".ml", ".mli", ".c", ".h"}
MLKIT_WORKLOADS = set("DLXSimulator PermuteList FuhMishra boyer checksum count-graphs fft fxp life longlife matrix-multiply mpuz msort msortrun peek perm perm1 professor professor2 professor_game psdes-random pseudokit ratio-regions raytrace smith-normal-form stringconcat tailfib tak tsp tyan vector-concat vector-rev wc-input1 wc-scanStream weeks4 zern kkb36c kkb36d kkb_eq klife_eq tststrcmp".split())
MLKIT_DEV_WORKLOADS = set("fib fib0 hanoi life listsort professor_game professor_game_debug rev many_refs".split())
# M2 source review: project members and entrypoint-only aliases.
MLKIT_REVIEW = {
    "test/kitmolgard_smlnj.sml": ("duplicate", "same complete generated Petri-net model, marking/transition logic, RNG and six-report workload as test/kitmolgard.sml; only callable launcher, old inputLine/Byte/Timer record adapters and integer versus Time elapsed-clock carriers differ; portable deterministic clock and SML97 adapters are shared under kitmolgard"),
    "test/fxp.sml": ("duplicate", "complete 17500-line FXP program is identical to mlton:benchmark/tests/fxp.sml after whitespace normalization, including data handling and invocation; retain the original source and notices under fxp"),
    "test/zern.sml": ("duplicate", "same complete FastRealArray2/MSpeed Zernike kernel and 128-square input as mlton:benchmark/tests/zern.sml; only the fixed 1000-repeat launcher replaces the parameterized launcher; retain the original count and source under zern"),
    "test/tsp.sml": ("duplicate", "same Tree/TSP/Rand/BuildTree algorithms as mlton:benchmark/tests/tsp.sml; selected size 32767 and four calls differ from MLton size 2097151 and parameterized calls; document these workload parameters and retain the source under tsp"),
    "test/tsp_tp.sml": ("duplicate", "same complete test/tsp.sml program except eight calls instead of four; repetition is a profile/driver parameter, not a separate algorithm or representation; retain both invocations under tsp"),
    "test/raytrace.sml": ("duplicate", "same full PLClub chess-scene renderer as mlton:benchmark/tests/raytrace.sml; only legacy Byte.unpackString tuple and unchecked lexer Vector/CharVector access differ, with both mapped to the same SML97 checked calls in the portable port; one-call launcher retained as provenance under raytrace"),
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
    "test/PermuteList.sml": ("exclude", "support module implementing PERMUTELIST and declaring projection/search functions; it contains no workload invocation, input or driver; retain it as a dependency if an importing application needs it"),
    "test_dev/life.sml": ("exclude", "compiler copy-string/debug regression: maps only the literal list [0,1] and prints progress; contains no Life evolution or benchmark invocation"),
    "test_dev/rev.sml": ("exclude", "two-element primitive printList/reversal compiler example using only [1,2]; no benchmark loop or representative input; larger list workloads are inventoried separately"),
    "test_dev/listsort.sml": ("exclude", "explicit Testing structure Listsort correctness program with test1/test2 boolean checks and Random.newgen; not the copying mergesort benchmark or a standalone sorting kernel"),
    "test/checksum.sml": ("duplicate", "same packed Word32 fold, ten-million-byte all-zero array and fifty scans as mlton:benchmark/tests/checksum.sml; legacy Pack32Little/fromLarge naming and invocation adapter are the only changes; retain both sources under checksum"),
    "test/boyer.sml": ("duplicate", "same complete property-list rewriting kernel, rules, substitution and theorem as mlton:benchmark/tests/boyer.sml; the fixed fifty-iteration wrapper and progress dots are driver differences, documented as original parameters/output adaptations under boyer"),
    "test/weeks4.sml": ("duplicate", "complete cyclic-u6 F17 Groebner kernel and twenty-repetition workload match mlton:benchmark/tests/tyan.sml; only author email spelling and parameterized versus fixed outer driver differ; retain this historical alias/source under tyan"),
    "test/pseudokit.sml": ("exclude", "module/type-sharing compiler regression declaring miniature Set/FinMap/Tools/Basics functors and one instantiation; no Pseudoknot calculation, input or timed workload despite its filename"),
    "test/professor2_smlnj.sml": ("duplicate", "same complete professor2 search, sixteen-card dataset and one-solve workload as test/professor2.sml; only opaque Main packaging and the callable invocation adapter differ; retain the alias source under professor2"),
    "test/kkb36c_mlton.sml": ("duplicate", "same no-op region functions, copying completion kernel, geometric equations and three completions as test/kkb36c_smlnj.sml; only the exposed launcher/helper name and unused testit differ; retain the host source under kkb36c_smlnj"),
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


def upstream_file(root, path):
    # Native reference builds leave caches with source-looking suffixes (for
    # example .cm/SKEL/main.sml); they are not pinned workload sources.
    ignored = {".cm", ".git", "MLB", "_build", "dist-newstyle", "__pycache__"}
    return not any(part in ignored for part in path.relative_to(root).parts)


def quoted_includes(root, files):
    files = list(files)
    pending = [p for p in files if p.suffix in {".hs", ".lhs", ".c", ".h"}]
    while pending:
        member = pending.pop()
        for name in re.findall(r'^\s*#\s*include\s*"([^"\n]+)"', member.read_text(errors="replace"), re.M):
            dependency = (member.parent / name).resolve()
            if dependency.is_relative_to(root) and dependency.is_file() and upstream_file(root, dependency):
                if dependency not in files:
                    files.append(dependency)
                    pending.append(dependency)
    return sorted(files)


def source_files(root, path):
    p = root / path
    if p.is_dir():
        return quoted_includes(root, sorted(q for q in p.rglob("*") if q.is_file() and q.suffix in EXTENSIONS and upstream_file(root, q)))
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
    return quoted_includes(root, files)


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


def nofib_feature_code(root, path):
    code = haskell_code(path)
    if (str(path.relative_to(root)) == "spectral/hartel/Fast2haskell.hs"
            and hashlib.sha256(path.read_bytes()).hexdigest() == "b94c6d53bd465be5b940bcbfec12c66c2ba971039072f91c0edb04558bea7596"):
        # Reviewed Fast shim: scalar bit operations and persistent arrays have
        # portable counterparts; delay/write are upstream error stubs. Keep
        # every other capability check and reject changed/unreviewed shims.
        code = re.sub(r"^\s*import\s+GHC\.Prim\s*;?", "", code, flags=re.M)
    return code


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
                if not upstream_file(root, p):
                    continue
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
            if not upstream_file(root, p):
                continue
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
    if key in {"happy", "hpg", "lift", "parstof", "transform"}:
        return "compiler-application"
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
            blockers = {
                "barnes-hut": "native SML/NJ 2026.2 CM.make fails at main.sml:7-61: BMARK.testit requires unit->unit but the source exports TextIO.outstream->unit; upstream also marks it broken; review/repair the launcher and establish independent full-state results before importing this variant",
                "delta-blue": "native SML/NJ 2026.2 CM.make succeeds, but Main.testit() fails constructing the second chain equality with Fail: Cycle encountered; projectionTest also checks dst instead of src after inverse propagation; repair and independently validate the constraint solver before import",
                "dlx": "native SML/NJ 2026.2 CM.make reports a missing end at main.sml:27 and a syntax error at line 42; its original launcher cannot run; repair the pinned modular variant and independently validate all trap outputs before import (older/newer monolithic DLX ports remain separate)",
                "kcfa": "sources.cm requires ../common/lib-base.sml, absent from the pinned checkout; native SML/NJ 2026.2 CM.make fails opening that module; restore/review its library exception contract and establish reference state/store summaries before import",
                "pia": "pinned programs/pia contains only DATA simulation datasets, with no SML implementation or build manifest; restore the advertised program and a runnable reference before considering a port",
                "regex": "advertised by upstream README but no programs/regex source directory exists at the pinned revision; restore the implementation and reference inputs/results before considering a port",
            }
            disposition, reason = "defer", blockers[name]
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
        if path == "spectral/constraints" and disposition == "import":
            canonical = root / "gc/constraints"
            candidate = root / path
            def profiles(directory):
                makefile = directory / "Makefile"
                if not makefile.is_file():
                    return []
                return re.findall(r"^(FAST_OPTS|NORM_OPTS|SLOW_OPTS)\s*=\s*(.*?)\s*$",
                                  makefile.read_text(), re.M)
            if (canonical / "Main.hs").is_file() and (candidate / "Main.hs").is_file():
                fixed = profiles(canonical)
                if (len(fixed) == 3 and {name for name, _ in fixed} == {"FAST_OPTS", "NORM_OPTS", "SLOW_OPTS"}
                        and fixed == profiles(candidate)
                        and (canonical / "Main.hs").read_bytes() == (candidate / "Main.hs").read_bytes()):
                    disposition = "duplicate"
                    reason = ("complete program, all five CSP algorithms, 240 repetitions and fixed "
                              "FAST/NORM/SLOW inputs match nofib:gc/constraints byte for byte; "
                              "GC heap flags are measurement configurations; share one implementation "
                              "and retain both source, fixture and runtime-setting provenances")
    if source == "sandmark":
        group = path.split("/")[1] if path.startswith("benchmarks/") else "external"
        if group in SANDMARK_PACKAGES or group == "external":
            disposition, reason = "defer", "requires the upstream application/package dependency graph (" + group + "); reconsider with a portable implementation of those dependencies"
        elif re.search(r"\b(?:effect\s+[A-Z]|Effect\.(?:Deep|Shallow|perform)|perform\s+|Domain\.(?:spawn|join)|Domainslib|Thread\.|Lwt[._]|Weak\.|Ephemeron\.|Gc\.(?:finalise|full_major|major|minor|compact|major_slice)|Gc\.get|Gc\.set|Obj\.|Ms_sched\.|external\s+\w+\s*:|Unix\.(?:fork|wait|create_process)|foreign_stubs|[Oo]camlcapi)", text):
            disposition, reason = "defer", "source uses OCaml-specific effects, concurrency, GC/weak-reference introspection, unsafe objects or C bindings; reconsider with equivalent runtime facilities"
        elif "multicore" in name or "parallel" in name or "multiprocess" in name or group in {"mpl", "multicore-gcroots", "multicore-structures", "multicore-grammatrix"}:
            disposition, reason = "defer", "parallel/runtime-specific executable; retain its original execution model"
        # Reviewed microprobes require %opaque to preserve their measured
        # operation. Do not generalize this to algorithmic uses of opacity.
        # These two modes measure typed C-layout Bigarray storage itself.
        # Replacing it with ordinary managed arrays changes the storage policy.
        if disposition == "import" and path == "benchmarks/stdlib/big_array_bench.exe":
            kernel = root / "benchmarks/stdlib/big_array_bench.ml"
            if (kernel.is_file() and hashlib.sha256(kernel.read_bytes()).hexdigest()
                    == "4df8ddc28ddc4fd81ad2db5938003b1857791b6e8c74e68a1559dfd043ffa0d6"):
                disposition, reason = "defer", (
                    "both pinned modes benchmark Bigarray int/int32 C-layout storage; "
                    "ordinary managed SML arrays change the measured storage policy; "
                    "reconsider with equivalent typed C-layout storage, without adding "
                    "runtime facilities through this benchmark roadmap")
        opaque_probes = {
            "benchmarks/simple-tests/morestacks.exe": (
                "b4153c8f1a4c4e9ea948113ee300fe62a7aee31e1ae0b69d79e121d4232eb946",
                "call-overhead microbenchmark relies on Sys.opaque_identity to retain "
                "calls to the otherwise inlineable n+5 function"),
            "benchmarks/simple-tests/alloc.exe": (
                "7649a3ae235416a6afc8e2f41297c51cf73fe8d40a6a573b5ea7ed7b24fea164",
                "allocation microbenchmark relies on Sys.opaque_identity create to "
                "retain calls and otherwise discarded mutable-record allocations"),
            "benchmarks/simple-tests/lists.exe": (
                "4a40532923d2fd783e47345740e64c9ec27f3305865d4e2730c80ba134d0e6e4",
                "typed-list allocation microbenchmark relies on Sys.opaque_identity "
                "create_list to retain otherwise discarded list generation in all nine modes"),
            "benchmarks/simple-tests/stacks.exe": (
                "6fcb3552d2efe34935766e5c13d6cd2b09b937d22a07e949855130bade0180f4",
                "stack/argument microbenchmark relies on Sys.opaque_identity to retain "
                "repeated calls whose integer/real recursive results are discarded in all four modes"),
            "benchmarks/simple-tests/stress.exe": (
                "dea8b3e283885c8bcbe468247fb923c4f488160688f40e44b5abbb055cd4ad70",
                "allocation/retention microbenchmark relies on Sys.opaque_identity ref "
                "to retain discarded references on its non-retaining branch"),
        }
        if disposition == "import" and path in opaque_probes:
            digest, explanation = opaque_probes[path]
            kernel = root / (path[:-4] + ".ml")
            if kernel.is_file() and hashlib.sha256(kernel.read_bytes()).hexdigest() == digest:
                disposition, reason = "defer", (
                    "pinned " + explanation + "; portable SML97 has no "
                    "equivalent optimization barrier; reconsider with a reviewed portable "
                    "barrier protocol or observable upstream workload, without adding "
                    "prerequisite compiler/runtime features through this roadmap")
        if disposition == "import" and path in {
                "benchmarks/multicore-effects/rec_seq_fib.exe",
                "benchmarks/multicore-effects/rec_seq_tak.exe"}:
            kernel = "fib" if name == "rec_seq_fib" else "tak"
            reason = ("reviewed strict recurrence matches the classic " + kernel
                      + " kernel; share one SML implementation and retain both provenances; "
                      "keep this established executable name and its original input/repetition "
                      "profiles, which differ from the classic launcher; document OCaml "
                      "operand evaluation order and consumed repetition results")
    if source == "mlton" and name == "tak":
        milestone = "M1"
    if source == "mlkit" and path == "test/kittmergesort.sml":
        milestone = "M1"
    if source == "nofib" and path == "imaginary/primes":
        milestone = "M1"
    if source == "sandmark" and path == "benchmarks/bdd/bdd.exe":
        milestone = "M1"
    if source == "nofib" and path == "spectral/dom-lt" and disposition == "import":
        module = root / "spectral/dom-lt/Dom.hs"
        if module.is_file() and hashlib.sha256(module.read_bytes()).hexdigest() == "ae7675a60f6915fee3f62c6e329b696e7f7a24324fc1cfac98fcaa1eff9094a1":
            reason = ("portable with reviewed semidominator-minimum repair; pinned source reuses "
                      "a stale threshold and returns incorrect parents on supplied graphs; preserve "
                      "original checksums while validating all corrected parents against independent results")
    return milestone, disposition, reason


def profile_inputs(root, parent):
    """Find literal file arguments without evaluating upstream Make or shell code."""
    makefile = parent / "Makefile"
    if not makefile.is_file():
        return set()
    text = makefile.read_text(errors="replace").replace("\\\n", " ")
    inputs = set()
    for value in re.findall(r"^\s*(?:FAST|NORM|SLOW)_OPTS\s*[:?+]?=\s*(.*)$", text, re.M):
        for token in shlex.split(value, comments=True):
            ref = token.split("=", 1)[-1] if token.startswith("--") else token
            if not re.fullmatch(r"[\w./@+ -]{1,240}", ref):
                continue
            candidate = (parent / ref).resolve()
            if candidate.is_relative_to(root) and candidate.is_file() and upstream_file(root, candidate):
                inputs.add(str(candidate.relative_to(root)))
    return inputs


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
        if source == "nofib" and path == "spectral/simple":
            # Reviewed historical Fortran comparator, outside SRCS=Main.hs.
            fortran = root / path / "simple.f"
            if fortran.is_file():
                files.append(fortran)
        files = sorted(set(files))
        text = "\n".join(p.read_text(errors="replace") for p in files if p.suffix in EXTENSIONS and p.suffix not in {".cm", ".mlb"})
        code = "\n".join(nofib_feature_code(root, p) for p in files) if source == "nofib" else code_only(text)
        milestone, disposition, reason = classify(source, root, item, files, code + "\n" + "\n".join(dependency_forms))
        name = item["name"]
        parent = (root / path) if (root / path).is_dir() else (root / path).parent
        inputs = profile_inputs(root, parent) if source == "nofib" else set()
        if files and parent.exists() and path.startswith(("programs/", "benchmarks/", "imaginary/", "spectral/", "real/", "gc/", "shootout/", "parallel/", "smp/")):
            for fixture in parent.rglob("*"):
                if not upstream_file(root, fixture):
                    continue
                if fixture.is_file() and (fixture.name == "ANSWER" or fixture.suffix in {".in", ".stdin", ".stdout", ".faststdin", ".faststdout", ".slowstdin", ".slowstdout", ".expected", ".out", ".ok"} or "DATA" in fixture.relative_to(parent).parts):
                    inputs.add(str(fixture.relative_to(root)))
        input_text = re.sub(r'^\s*#\s*include[^\n]*$', '', text, flags=re.M)
        for ref in re.findall(r'"([^"\n]+)"', input_text):
            if not re.fullmatch(r"[\w./@+ -]{1,240}", ref):
                continue
            candidate = (parent / ref).resolve()
            if candidate.is_relative_to(root) and candidate.is_file():
                inputs.add(str(candidate.relative_to(root)))
        notices = lock["notices"].split(";") if lock["notices"] not in {"", "-"} else []
        if files and parent.exists() and ((root / path).is_dir() or source == "nofib" or (source == "sandmark" and path.startswith("benchmarks/"))):
            for notice in parent.rglob("*"):
                if not upstream_file(root, notice):
                    continue
                if notice.is_file() and re.fullmatch(r"(?:LICENSE|COPYING|COPYRIGHT)(?:\.[\w-]+)?", notice.name, re.I):
                    notices.append(str(notice.relative_to(root)))
        authors = set()
        context = [p for p in parent.iterdir() if p.is_file() and p.name in {"README", "README.md", "Makefile", "FILES", "sources.cm"}] if parent.exists() and files else []
        if source == "nofib" and path == "real/hpg":
            manual = parent / "hpg.tex"
            if manual.is_file():
                heading = manual.read_text(errors="replace")
                if (r"\title{The Haskell Program Generator}" in heading
                        and r"\author{N D North" in heading
                        and "ndn@seg.npl.co.uk" in heading):
                    authors.add("N. D. North")
                    item["evidence"].append(path + "/hpg.tex:program-author-title-and-address")
                if "% Crown Copyright 1992" in heading:
                    notices.append(path + "/hpg.tex:Crown-Copyright-1992")
        if source == "nofib" and path == "real/reptile":
            module = parent / "Main.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:1000]
                if "-- LML original: Sandra Foubister, 1990" in heading:
                    authors.add("Sandra Foubister (LML original)")
                    item["evidence"].append(path + "/Main.hs:LML-original-credit")
                if "-- Haskell translation: Colin Runciman, May 1991" in heading:
                    authors.add("Colin Runciman (Haskell translation)")
                    item["evidence"].append(path + "/Main.hs:Haskell-port-credit")
        if source == "nofib" and path == "real/fluid":
            definitions = parent / "Defs.hs"
            if definitions.is_file():
                heading = definitions.read_text(errors="replace")[:1000]
                if (re.search(r"\bXZ,\s*24/10/91\b", heading)
                        and re.search(r"\bXZ,\s*19/2/92\b", heading)):
                    authors.add("XZ (source initials)")
                    item["evidence"].append(path + "/Defs.hs:dated-source-initials-not-expanded")
            data = parent / "runtime_files/chan8.dat"
            if data.is_file():
                inputs.add(str(data.relative_to(root)))
                item["evidence"].append(path + "/runtime_files/chan8.dat:runtime-mesh-input")
                heading = data.read_text(errors="replace")[:1000]
                if "TEST CHANNEL PROBLEM WITH NONISOTHERMAL FLOW" in heading:
                    item["evidence"].append(path + "/runtime_files/chan8.dat:channel-model-header")
        if source == "nofib" and path == "spectral/hartel/nucleic2":
            main = parent / "Main.hs"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("Author: Marc Feeley (feeley@iro.umontreal.ca)" in heading
                        and "Last modified: June 6, 1994" in heading):
                    authors.add("Marc Feeley")
                    item["evidence"].append(path + "/Main.hs:molecular-search-author-and-date")
                if "#ifdef USE_HARTEL_LAZINESS" in heading and "make_relative_nuc t n" in heading:
                    item["evidence"].append(path + "/Main.hs:on-demand-and-shared-coordinate-variants")
            readme = parent / "README"
            if readme.is_file():
                readme_text = readme.read_text(errors="replace")
                if "Haskell version (for HBC, by Lennart Augustsson)" in readme_text:
                    authors.add("Lennart Augustsson (Haskell version)")
                    item["evidence"].append(path + "/README:Haskell-port-authorship")
                if "UPDATE(2017.01)" in readme_text and "non-Haskell versions of the program" in readme_text:
                    item["evidence"].append(path + "/README:historical-archive-files-removed-in-2017")
            mail = parent / "MAIL"
            if mail.is_file():
                context.append(mail)
                correspondence = mail.read_text(errors="replace")
                if ("From: pieter@fwi.uva.nl (Pieter H. Hartel)" in correspondence
                        and "Subject: Request participation pseudo knot benchmark" in correspondence
                        and "Mon, 13 Jun 1994" in correspondence):
                    authors.add("Pieter H. Hartel (benchmark coordination)")
                    item["evidence"].append(path + "/MAIL:1994-benchmark-coordination-and-porting-invitation")
            header = parent / "unboxery.h"
            if header.is_file():
                header_text = header.read_text(errors="replace")
                if (re.search(r"^#define FLOAT_TY Float\s*$", header_text, re.M)
                        and "#define FL_LIT(x) (x)" in header_text):
                    item["evidence"].append(path + "/unboxery.h:boxed-Float-default")
        if source == "nofib" and path == "gc/happy":
            main = parent / "Main.lhs"
            if main.is_file():
                heading = main.read_text(errors="replace")[:1000]
                if "(c) 1993-2003 Andy Gill, Simon Marlow" in heading:
                    authors.update({"Andy Gill", "Simon Marlow"})
                    item["evidence"].append("gc/happy/Main.lhs:original-authors")
            data = parent / "TestInput.y"
            if data.is_file():
                heading = data.read_text(errors="replace")[:1000]
                if ("(c) The University of Glasgow 1997-2003" in heading
                        and "Author(s): Simon Marlow, Sven Panne 1997, 1998, 1999" in heading):
                    authors.add("Sven Panne (GHC grammar input)")
                    notices.append("gc/happy/TestInput.y:Glasgow-copyright-and-grammar-authors")
                    item["evidence"].append("gc/happy/TestInput.y:individual-dataset-notice")
            utilities = parent / "GenUtils.lhs"
            if utilities.is_file() and "All the code below is understood to be in the public domain." in utilities.read_text(errors="replace")[:1000]:
                notices.append("gc/happy/GenUtils.lhs:public-domain-statement")
                item["evidence"].append("gc/happy/GenUtils.lhs:individual-public-domain-statement")
            makefile = parent / "Makefile"
            if makefile.is_file():
                build_text = makefile.read_text()
                if "NORM_OPTS = TestInput.y" in build_text and "EXCLUDED_SRCS += TestInput.hs" in build_text:
                    item["evidence"].append("gc/happy/Makefile:grammar-input-and-generated-parser-exclusion")
        if source == "nofib" and path == "spectral/simple":
            main = parent / "Main.hs"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("Original Author: Kattamuri Ekanadham <EKNATH@ibm.com>" in heading
                        and "translated to haskell by an id to ph translator" in heading):
                    item["evidence"].append("spectral/simple/Main.hs:Id-author-and-anonymous-translator-role")
            c_source = parent / "simple.c"
            if c_source.is_file():
                heading = c_source.read_text(errors="replace")[:1000]
                if ("Andy Shaw and Kofi Fynn." in heading
                        and "Wed Feb  2 14:59:18 EST 1994" in heading):
                    authors.update({"Andy Shaw (C comparator)", "Kofi Fynn (C comparator)"})
                    item["evidence"].append("spectral/simple/simple.c:C-comparator-authors")
            mail = parent / "MAIL"
            if mail.is_file():
                context.append(mail)
                correspondence = mail.read_text(errors="replace")
                if ("RPaul Johnson told me" in correspondence
                        and "This version may be useful because it is in 1.2 Haskell" in correspondence):
                    authors.add("RPaul Johnson (Haskell/pH correspondence)")
                    item["evidence"].append("spectral/simple/MAIL:Haskell-port-correspondence")
                if "Here is the fortran in its original form from Olaf Lubeck:" in correspondence:
                    authors.add("Olaf Lubeck (Fortran supplier, not asserted sole author)")
                    item["evidence"].append("spectral/simple/MAIL:Fortran-supplier")
            makefile = parent / "Makefile"
            if makefile.is_file() and "SRCS = Main.hs" in makefile.read_text():
                item["evidence"].append("spectral/simple/Makefile:excludes-C-and-Fortran-comparators")
        if source == "nofib" and path == "real/lift":
            paper = parent / "LambdaLift.lhs"
            if paper.is_file():
                heading = paper.read_text(errors="replace")
                if (r"\title{A modular fully-lazy lambda lifter in \Haskell{}}" in heading
                        and "Simon L Peyton Jones" in heading
                        and "David Lester" in heading
                        and r"\begin{abstract}" in heading):
                    authors.update({"Simon L. Peyton Jones", "David Lester"})
                    item["evidence"].append("real/lift/LambdaLift.lhs:executable-paper-title-and-author-block")
        if source == "nofib" and path == "real/fem":
            readme = parent / "README"
            if readme.is_file():
                heading = readme.read_text(errors="replace")
                if ("Dr. Junxian Liu" in heading and "Department of Computing" in heading
                        and "Imperial College, London SW7 2BZ" in heading):
                    authors.add("Junxian Liu")
                    item["evidence"].append("real/fem/README:author-and-model-description")
            for name in ("data.0", "data.1", "data.2", "data.3"):
                data = parent / name
                if data.is_file():
                    inputs.add(str(data.relative_to(root)))
                    item["evidence"].append("real/fem/" + name + ":reviewed-model-input")
        if source == "nofib" and path in {"gc/cacheprof", "real/cacheprof"}:
            module = parent / "Main.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("Copyright (C) 1999 Julian Seward (jseward@acm.org)" in heading
                        and "either version 2 of the" in heading
                        and "License, or (at your option) any later version." in heading):
                    authors.add("Julian Seward")
                    item["evidence"].append(path + "/Main.hs:author-and-GPL2-or-later-heading")
            full = parent / "cacheprof.full"
            if full.is_file():
                inputs.add(str(full.relative_to(root)))
                item["evidence"].append(path + "/cacheprof.full:complete-assembly-input-reservoir")
        if source == "nofib" and path in {"gc/fulsom/Main.hs", "real/fulsom/Main.hs",
                                          "gc/fulsom/Bah.hs", "real/fulsom/Bah.hs"}:
            module = parent / "Interval.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("Copyright 1990,1991,1992,1993 Duncan Sinclair" in heading
                        and "Permissiom to use, copy, modify, and distribute this software for any" in heading
                        and "copyright notice and this permission notice appear in all copies" in heading):
                    authors.add("Duncan Sinclair")
                    item["evidence"].append(str(module.relative_to(root)) + ":author-and-individual-permission")
        if source == "nofib" and path == "real/hidden" and (parent / "MAIL").is_file():
            # Reviewed correspondence credits both roles and grants nofib use.
            mail = (parent / "MAIL").read_text(errors="replace")
            if ('From:    ramaer@cs.utwente.nl (Mark Ramaer)' in mail
                    and 'Certainly.  However, I should note that the program is written by\n'
                        'Stef Joosten (joosten@cs.utwente.nl) in Miranda(TM) and I have translated\n'
                        'it to Haskell to play with overloading; I also added the memoising.' in mail):
                authors.update(["Stef Joosten", "Mark Ramaer"])
                item["evidence"].append("real/hidden/MAIL:authorship-and-nofib-permission")
                notices.append("real/hidden/MAIL:nofib-permission")
        if source == "nofib" and path == "real/gg" and (parent / "gg.1").is_file():
            manual = (parent / "gg.1").read_text(errors="replace")
            if ".SH AUTHOR\nIain Checkland, University of York." in manual:
                authors.add("Iain Checkland")
                item["evidence"].append("real/gg/gg.1:author-section")
        if source == "nofib" and path == "spectral/fft2" and (parent / "Main.lhs").is_file():
            header = (parent / "Main.lhs").read_text(errors="replace")
            if "Rex Page (rpage@trc.amoco.com)" in header and "Amoco Production Research, Sep 1992" in header:
                authors.add("Rex Page")
                item["evidence"].append("spectral/fft2/Main.lhs:author-header")
        if source == "nofib" and path == "spectral/lambda" and (parent / "Main.hs").is_file():
            header = (parent / "Main.hs").read_text(errors="replace")
            if "-- From Mark: marku@cs.waikato.ac.nz [Nov 2001]" in header:
                authors.add("Mark (marku@cs.waikato.ac.nz)")
                item["evidence"].append("spectral/lambda/Main.hs:author-header")
        if source == "nofib" and path == "spectral/para" and (parent / "Main.lhs").is_file():
            header = (parent / "Main.lhs").read_text(errors="replace")
            if "% \tA program by Oege de Moor and Jeremy Gibbons" in header:
                authors.update(("Oege de Moor", "Jeremy Gibbons"))
                item["evidence"].append("spectral/para/Main.lhs:author-heading")
            data = parent / "runtime_files/input-data"
            if data.is_file():
                text = data.read_text(errors="replace")
                if ("Far From The Madding Crowd, by Thomas Hardy" in text and
                        "*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*" in text):
                    notices.append("spectral/para/runtime_files/input-data:Project-Gutenberg-1993-notice")
                    item["evidence"].append("spectral/para/runtime_files/input-data:individual-dataset-notice")
        if source == "nofib" and path == "spectral/sphere" and (parent / "Main.lhs").is_file():
            header = (parent / "Main.lhs").read_text(errors="replace")
            if ("16 July, 1998, David J. King" in header and
                    "This is a Haskell port of the Id version from the Impala" in header):
                authors.add("David J. King")
                item["evidence"].append("spectral/sphere/Main.lhs:authorship-and-port-history")
        if source == "nofib" and path == "spectral/rewrite":
            module = parent / "Main.lhs"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if "Mike Spivey," in heading and "St. George's Day, 1991." in heading and "[converted to Haskell by partain]" in heading:
                    authors.update(["Mike Spivey", "partain (Haskell conversion)"])
                    item["evidence"].append("spectral/rewrite/Main.lhs:Orwell-author-and-Haskell-conversion-heading")
        if source == "nofib" and path == "spectral/dom-lt":
            module = parent / "Dom.hs"
            if module.is_file():
                heading = module.read_text(errors="replace")
                if "Copyright   :  (c) Matt Morrow 2009" in heading and "License     :  BSD3" in heading:
                    authors.add("Matt Morrow")
                    item["evidence"].append("spectral/dom-lt/Dom.hs:algorithm-author-and-BSD3-heading")
        if source == "nofib" and path == "spectral/multiplier":
            main = parent / "Main.hs"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("-- John O'Donnell, University of Glasgow. jtod@dcs.glasgow.ac.uk" in heading
                        and "-- Copyright (c) 1992 by John T. O'Donnell" in heading):
                    authors.add("John T. O'Donnell")
                    item["evidence"].append("spectral/multiplier/Main.hs:author-and-copyright-heading")
        if source == "sandmark" and path == "benchmarks/lexifi-g2pp/main.exe":
            module = parent / "main.ml"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("Copyright (C) 2000-2013 LexiFi SAS. All rights reserved." in heading
                        and "either version 3 of the License" in heading):
                    authors.add("LexiFi SAS (copyright holder)")
                    item["evidence"].append("benchmarks/lexifi-g2pp/main.ml:copyright-holder-and-GPL3-heading")
        if source == "sandmark" and path == "benchmarks/multicore-minilight/sequential/minilight.exe":
            module = parent / "minilight.ml"
            if module.is_file():
                heading = module.read_text(errors="replace")[:1000]
                if ("MiniLight OCaml : minimal global illumination renderer" in heading
                        and "Copyright (c) 2006-2008, Harrison Ainsworth / HXA7241." in heading):
                    authors.add("Harrison Ainsworth / HXA7241")
                    item["evidence"].append("benchmarks/multicore-minilight/sequential/minilight.ml:author-and-release-heading")
        if source == "sandmark" and path == "benchmarks/sauvola/contrast.exe":
            module = parent / "contrast.ml"
            if module.is_file():
                heading = module.read_text(errors="replace")[:2500]
                if ("(c) 2009-12 Andreas Romeyke" in heading
                        and "GNU General Public License" in heading and "(v2.0 or higher)" in heading):
                    authors.add("Andreas Romeyke")
                    item["evidence"].append("benchmarks/sauvola/contrast.ml:author-and-GPL2-heading")
        if source == "sandmark" and path == "benchmarks/benchmarksgame/regexredux2.exe":
            main = parent / "regexredux2.ml"
            if main.is_file():
                heading = main.read_text(errors="replace")
                if ("regex-dna program contributed by Christophe TROESTLER" in heading
                        and "updated by Roman Kashitsyn: use Bytes instead of String" in heading):
                    authors.add("Roman Kashitsyn")
                    item["evidence"].append("benchmarks/benchmarksgame/regexredux2.ml:Bytes-adaptation-credit")
        if source == "nofib" and path == "spectral/expert":
            readme = parent / "README"
            if readme.is_file() and "Ian Holyer\nMarch 1993" in readme.read_text(errors="replace"):
                authors.add("Ian Holyer")
                item["evidence"].append("spectral/expert/README:authorship-and-adaptation-heading")
        if source == "nofib" and path == "spectral/knights":
            readme = parent / "README"
            if readme.is_file() and "The Knights Tour in Haskell\n---------------------------\n\nJonathan Hill\n" in readme.read_text(errors="replace"):
                authors.add("Jonathan Hill")
                item["evidence"].append("spectral/knights/README:authorship-heading")
        if source == "nofib" and path in {"gc/linear", "real/linear"}:
            main = parent / "Main.lhs"
            if main.is_file():
                text = main.read_text(errors="replace")
                if ("Written by Brian D. Moe (Summer 1990)" in text and
                        "Modified by Kamini Shenoi (Summer 1991)" in text and
                        "Converted to Haskell by Ian R McLelland and Cordelia V Hall (Nov 1992)" in text):
                    authors.update(("Brian D. Moe", "Kamini Shenoi", "Ian R. McLelland", "Cordelia V. Hall"))
                    item["evidence"].append(path + "/Main.lhs:authorship-and-conversion-roles")
            data = parent / "Input.lhs"
            if data.is_file():
                text = data.read_text(errors="replace")
                if "Roger L. Wainwright  6-8-90" in text:
                    authors.add("Roger L. Wainwright")
                    item["evidence"].append(path + "/Input.lhs:data-representation-credit")
                if "written by Dan Vasicek and copied from his directory 6/22/90" in text:
                    authors.add("Dan Vasicek")
                    item["evidence"].append(path + "/Input.lhs:input-reader-credit")
        item["evidence"].extend(str(p.relative_to(root)) for p in context)
        for p in files + context:
            header = p.read_text(errors="replace")[:8000]
            if (source == "nofib" and path in {"gc/circsim", "spectral/circsim"}
                    and "The Circuit Simulator example\nDavid J. King & John O'Donnell\nJanuary, 1998" in header):
                authors.update(["David J. King", "John O'Donnell"])
                item["evidence"].append(str(p.relative_to(root)) + ":authorship-heading")
            if (source == "nofib" and path == "spectral/atom"
                    and "A kernel fragment from a program written by\n\t\tRon Legere" in header):
                authors.add("Ron Legere")
                item["evidence"].append(str(p.relative_to(root)) + ":attribution-header")
            if (source == "nofib" and path == "spectral/exact-reals"
                    and '-- Taken from "The worlds shortest correct exact real arithmetic program?"\n-- David Lester, Information and Computation 216, pp39-46, 2012, Elsevier' in header):
                authors.add("David Lester")
                item["evidence"].append(str(p.relative_to(root)) + ":paper-attribution")
            if (source == "nofib" and path in {"real/pic", "real/gamteb"}
                    and re.search(r"(?m)^--[ \t]+Patricia Fasel\n--[ \t]+Los Alamos National Laboratory", header)):
                authors.add("Patricia Fasel")
                item["evidence"].append(str(p.relative_to(root)) + ":author-heading")
            if (source == "nofib" and path == "real/prolog"
                    and re.search(r"(?m)^-- Mark P\. Jones November 1990$", header)):
                authors.add("Mark P. Jones")
                item["evidence"].append(str(p.relative_to(root)) + ":author-heading")
            if (source == "nofib" and path == "real/mkhprog"
                    and r"\author{N D North\\" in header.splitlines()
                    and "% Crown Copyright 1992" in header.splitlines()):
                authors.add("N. D. North")
                item["evidence"].append(str(p.relative_to(root)) + ":author-and-crown-heading")
            reviewed_prime_author = (
                source == "nofib" and path == "spectral/primetest"
                and r"\def\author{David Lester}" in header.splitlines())
            if reviewed_prime_author:
                authors.add("David Lester")
                item["evidence"].append(str(p.relative_to(root)) + ":author-macro")
            if re.search(r"[Cc]opyright|[Ll]icen[sc]e|[Ww]ritten by|[Aa]uthor:|[Tt]ranslated", header):
                notices.append(str(p.relative_to(root)) + ":header")
            for attribution in re.finditer(r"(?:[Ww]ritten|[Tt]ranslated|[Pp]orted|[Cc]ontributed)(?: to [^\n]*?)? by ([^\n]+)|[Aa]uthors?: ([^\n]+)", header):
                if (reviewed_prime_author and attribution.start() > 0
                        and header[attribution.start() - 1] == "$"):
                    continue  # The RCS last-committer tag is not the declared author.
                author = (attribution.group(1) or attribution.group(2)).strip(" *()-")
                if author == "Marc Feeley (feeley@iro.umontreal.ca":
                    author = "Marc Feeley"
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
    aliases = {"nucleic": "pseudoknot", "nucleic2": "pseudoknot", "DLXSimulator": "dlx", "smith-nf": "smith-normal-form", "kb": "knuth-bendix",
               "rec_seq_fib": "fib", "rec_seq_tak": "tak", "rec_seq_evenodd": "even-odd"}
    groups = collections.defaultdict(list)
    for row in rows:
        base = re.sub(r"_(smlnj|mlton|tp|no_basislib)$", "", row["name"])
        groups[aliases.get(base, base)].append(row)
    for group in groups.values():
        for row in group:
            row["related"] = ";".join(sorted(other["source"] + ":" + other["path"] for other in group if other is not row))


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
