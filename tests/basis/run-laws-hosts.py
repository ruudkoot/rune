#!/usr/bin/env python3
"""The laws of the Basis Library's documentation on the other compilers
(docs/plans/quickcheck.md, D10).

    tests/basis/run-laws-hosts.py [HOST...]

The programs of `runedoc --laws` are built by MLton, SML/NJ (64 and 32 bits,
and the development line), Poly/ML and MLKit against their own Basis Library,
with lib/random, lib/test/property and lib/test/property/basis, and run with
the settings of `make check`, $LAWS_HOST_JOBS hosts at once (default 3). A law
is held at a structure only where the host has what it names: a probe asks
each host which of the structures the programs name it has, and a file of the
libraries that tests/lib/run-hosts.sh leaves out (host column no) is built
where the structures it requires are there, and left out where an error points
into it. Each host builds a program of its own: a law's entry, or where the
host lacks what that names or it does not build there, the law's alternative
entry (PROGRAM.alt of `runedoc --laws`), which draws its types by the
arbitraries of the structure's own family, as a host may tell apart types that
Rune's are one of (`Real64VectorArb` for `Real64Vector.vector`, where the
entry takes `LargeRealVectorArb`). A program that still does not build loses
the laws its errors are in, and is built again; those laws are NOT BUILT on
the host, with the first error. A program the host stops (SML/NJ's "bogus
fault", or after $LAWS_HOST_TIMEOUT seconds) goes on after the law it was in,
which is STOPPED. A law that fails is run again by itself, three times at most
where the host stops before a verdict: as the programs are deterministic, a
verdict that changes is FLAKY, the host's.

The verdicts are compared with Rune's (tests/out/laws/results.txt, or
$LAWS_RESULTS): a law that passes on one and fails on the other is a
DIFFERENCE, which the hunt classifies -- the law, Rune, or the host (a host's
bug is a line of tests/basis/law-deviations.txt). A law that fails on both is
AGREED. In tests/out/laws-hosts: HOST.structures, what the host lacks of the
names the programs use; HOST.library, the files it builds; HOST/, each
program as the host builds it and its output; HOST.alternatives, the laws
it holds by their alternative entries; HOST.results; and
differences.txt. `--compare [HOST...]` judges the results there again, as
after a change to the deviations.
"""
import concurrent.futures
import fnmatch
import os
import re
import signal
import subprocess
import sys

TOP = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(TOP)
HOSTS_DIR = os.environ.get("RUNE_HOSTS", os.path.expanduser("~/.local/rune-hosts"))
BIN = {
    "mlton": os.environ.get("MLTON", HOSTS_DIR + "/mlton/bin/mlton"),
    "smlnj-legacy": os.environ.get("SMLNJ", HOSTS_DIR + "/smlnj-legacy/bin/sml"),
    "smlnj32": os.environ.get("SMLNJ32", HOSTS_DIR + "/smlnj32/bin/sml"),
    "smlnj-dev": os.environ.get("SMLNJ_DEV", HOSTS_DIR + "/smlnj-dev/bin/sml"),
    "polyml": os.environ.get("POLY", HOSTS_DIR + "/polyml/bin/poly"),
    "mlkit": os.environ.get("MLKIT", HOSTS_DIR + "/mlkit/bin/mlkit"),
}
MLKIT_LIB = os.environ.get("MLKIT_LIB", HOSTS_DIR + "/mlkit/lib/mlkit")
RUNEDOC = os.environ.get("RUNEDOC", "bin/runedoc")
RESULTS = os.environ.get("LAWS_RESULTS", "tests/out/laws/results.txt")
DEVIATIONS = os.environ.get("LAWS_DEVIATIONS", "tests/basis/law-deviations.txt")
SKIPS = os.environ.get("LAWS_SKIPS", "tests/basis/law-skips.txt")
TIMEOUT = int(os.environ.get("LAWS_HOST_TIMEOUT", "600"))      # seconds for a program to build and run, each time
MEMORY = int(os.environ.get("LAWS_HOST_MEMORY", "8192"))        # megabytes, for a host and its program
JOBS = int(os.environ.get("LAWS_HOST_JOBS", "3"))               # hosts at once: six at once, MLton building
                                                                # beside the others, can fill the machine
OUT = os.path.join(TOP, "tests/out/laws-hosts")
PROGRAMS = os.environ.get("LAWS_PROGRAMS", "")    # a regular expression: only the programs it matches
ATTEMPTS = 12      # builds of a program, each without the laws the errors before were in
RANDOM = ["lib/random/random_sig.sml", "lib/random/random.sml"]


def run(cmd, cwd=None, stdin=None, timeout=None, env=None):
    """the command's status and its output, stdout and stderr together; a
    command that runs past its time is stopped with every process it started
    (sml and a use file through sh are more than one)"""
    limit = "ulimit -v %d; " % (MEMORY * 1024)
    p = subprocess.Popen(["sh", "-c", limit + 'exec "$@"', "sh"] + cmd, cwd=cwd, stdin=stdin,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, start_new_session=True)
    try:
        out, _ = p.communicate(timeout=timeout)
        return p.returncode, out.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        out, _ = p.communicate()
        return -1, out.decode("utf-8", "replace") + "\n(stopped after %d s)\n" % timeout


# ---- the library: which files of lib/test/property a host builds ----

def manifest():
    """the files of lib/test/property and of its Basis instances,
    lib/test/property/basis, in load order: (path, host, provides, requires)"""
    files = []
    for d in ("lib/test/property", "lib/test/property/basis"):
        for line in open(d + "/MANIFEST"):
            if line.startswith("#") or "|" not in line:
                continue
            f, _, host, provides, requires = [c.strip() for c in line.split("|")[:5]]
            files.append((d + "/" + f, host, provides.split(), requires.split()))
    return files


def library_names(files):
    """the names lib/test/property and lib/random provide"""
    names = {n for _, _, provides, _ in files for n in provides}
    for line in open("lib/random/MANIFEST"):
        if not line.startswith("#") and "|" in line:
            names.update(line.split("|")[3].split())
    return names


def library_for(files, present, dropped=()):
    """the files a host builds, in order, and the names they provide: a file
    of host column no only where all it requires is there, and it is not
    one the host was found not to build"""
    lib_names = library_names(files) - {n for f, _, provides, _ in files for n in provides}
    provided, chosen = set(lib_names), []
    for f, host, provides, requires in files:
        ok = all((r in provided) if r in library_names(files) else (r in present) for r in requires)
        if (host == "yes" or ok) and f not in dropped:
            chosen.append(f)
            provided.update(provides)
    return chosen, provided


def library_on(host, files, present, workdir):
    """the files of the library the host builds: a file of host column no
    that does not build there (its API is Rune's own, as INet6Sock's) is
    left out, with what requires it"""
    dropped = set()
    for _ in range(len(files)):
        chosen, provided = library_for(files, present, dropped)
        main = os.path.join(workdir, "library.sml")
        open(main, "w").write("val () = print \"library built\\n\"\n")
        built, output, msgs, _ = build(host, "library", RANDOM + chosen + [main], workdir)
        if built:
            return chosen, provided, dropped
        # the file an error points into (MLKit names every file it reads)
        bad = [f for f in chosen if error_lines(host, msgs, f) and
               dict((g, h) for g, h, _, _ in files).get(f) == "no"]
        if not bad:
            raise SystemExit("%s: lib/test/property does not build:\n%s" % (host, first_error(msgs)))
        dropped.add(bad[0])
    raise SystemExit(host + ": lib/test/property does not build")


# ---- the programs and their laws ----

QUALIFIED = re.compile(r"\b([A-Z][A-Za-z0-9_']*(?:\.[A-Z][A-Za-z0-9_']*)*)\.(?:[a-z~!%&$#+/:<=>?@\\^|*`-]|[A-Z][A-Za-z0-9_']*\b(?!\.))")


def split_program(text):
    """the head of a program, its entries (label, text) and its tail"""
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if l.startswith('  ("')]
    if not starts:
        return text, [], ""
    head = "\n".join(lines[:starts[0]])
    entries = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        body = "\n".join(lines[s:e]).rstrip()
        if k + 1 == len(starts):
            assert body.endswith("]"), body[-40:]
            body = body[:-1]
        elif body.endswith(","):
            body = body[:-1]
        label = body[4:body.index('"', 4)]
        entries.append((label, body))
    return head, entries, "]\n"


def names_in(entry_text):
    """the structure paths an entry names, as `Real.Math` for `Real.Math.atan2`"""
    names = set()
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', entry_text)      # not inside strings
    for m in QUALIFIED.finditer(code):
        path = m.group(1)
        # `Int.maxInt` names Int; `Date.Jan` names Date (a constructor); `OS.Path.x` OS.Path
        names.add(path)
    names.update(opens_in(entry_text))
    return names


def opens_in(entry_text):
    """the structures an entry opens, under which a path may be relative:
    `StreamIO` is `BinIO.StreamIO` in `let open BinIO in ... StreamIO.input`"""
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', entry_text)
    return [p for m in re.finditer(r"let open ([A-Za-z0-9_. ]+?) in", code) for p in m.group(1).split()]


def opened(entry_text):
    """(a structure the entry opens, a path the entry names) for each pair"""
    return {(o, n) for o in opens_in(entry_text) for n in names_in(entry_text) if n != o}


def prefixes(path):
    parts = path.split(".")
    return [".".join(parts[:k]) for k in range(1, len(parts) + 1)]


# ---- the hosts ----

def probe(host, names, workdir, kind="structure"):
    """the names of `names` that the host does not have, as structures or
    as signatures (OS, IO and SML90 are structures, CHAR a signature)"""
    names = sorted(names)
    lines = ["%s P%d = %s" % (kind, i, n) for i, n in enumerate(names)]
    src = os.path.join(workdir, "probe.sml")
    open(src, "w").write("\n".join(lines) + "\n")
    if host == "mlton":
        open(os.path.join(workdir, "probe.mlb"), "w").write("$(SML_LIB)/basis/basis.mlb\nprobe.sml\n")
        _, text = run([BIN[host], "-stop", "tc", "probe.mlb"], cwd=workdir)
        bad = {int(m.group(1)) for m in re.finditer(r"probe\.sml (\d+)\.\d+", text)}
    elif host.startswith("smlnj"):
        _, text = run([BIN[host], "probe.sml"], cwd=workdir, stdin=subprocess.DEVNULL)
        bad = {int(m.group(1)) for m in re.finditer(r"probe\.sml:(\d+)\.\d+", text)}
    elif host == "polyml":
        _, text = run(["sh", "-c", 'echo \'use "probe.sml";\' | "$0" -q', BIN[host]], cwd=workdir)
        bad = {int(m.group(1)) for m in re.finditer(r"probe\.sml:(\d+): error", text)}
    elif host == "mlkit":
        open(os.path.join(workdir, "probe.mlb"), "w").write("$(SML_LIB)/basis/basis.mlb\nprobe.sml\n")
        _, text = run([BIN[host], "-o", "probe", "probe.mlb"], cwd=workdir,
                      env=dict(os.environ, SML_LIB=MLKIT_LIB))
        bad = {int(m.group(1)) for m in re.finditer(r"probe\.sml, line (\d+), column", text)}
    else:
        raise SystemExit("unknown host " + host)
    return {names[i - 1] for i in bad if 1 <= i <= len(names)}


def missing_on(host, names, workdir):
    """the names the host has neither as a structure nor as a signature"""
    missing, rest = set(), set(names)
    # again without the names found: MLKit reports at most 50 errors
    while rest:
        found = probe(host, rest, workdir)
        if not found:
            break
        missing |= found
        rest -= found
    sigs = {n for n in missing if "." not in n and re.fullmatch(r"[A-Z][A-Z0-9_]*", n)}
    if not sigs:
        return missing
    found = sigs - probe(host, sigs, workdir, kind="signature")
    return missing - found


def build(host, name, files, workdir):
    """build and run a program: (built, its output, the build's messages, a
    function that runs it again from after a law)"""
    absfiles = [os.path.join(TOP, f) for f in files]
    def env_after(after, only=""):
        env = dict(os.environ)
        if after:
            env["RUNE_PROPERTY_AFTER"] = after
        if only:
            env["RUNE_PROPERTY_ONLY"] = only
        return env
    if host in ("mlton", "mlkit"):
        mlb = os.path.join(workdir, name + ".mlb")
        open(mlb, "w").write("$(SML_LIB)/basis/basis.mlb\n" + "\n".join(absfiles) + "\n")
        if host == "mlton":
            status, msgs = run([BIN[host], "-output", name, name + ".mlb"], cwd=workdir)
        else:
            status, msgs = run([BIN[host], "-o", name, name + ".mlb"], cwd=workdir,
                               env=dict(os.environ, SML_LIB=MLKIT_LIB))
        if status != 0:
            return False, "", msgs, None
        def again(after, only=""):
            return run(["./" + name], cwd=workdir, timeout=TIMEOUT, env=env_after(after, only))[1]
        return True, again(""), msgs, again
    if host.startswith("smlnj"):
        exit_sml = os.path.join(workdir, "exit.sml")
        open(exit_sml, "w").write("val () = OS.Process.exit OS.Process.success\n")
        def again(after, only=""):
            return run([BIN[host]] + absfiles + [exit_sml], cwd=workdir, stdin=subprocess.DEVNULL,
                       timeout=TIMEOUT, env=env_after(after, only))[1]
        raw = again("")
        built = not re.search(r"\.sml:\d+\.\d+(-\d+\.\d+)? Error:", raw)
        return built, raw, raw if not built else "", again
    if host == "polyml":
        use = os.path.join(workdir, name + ".use")
        open(use, "w").write("".join('use "%s";\n' % f for f in absfiles) + "OS.Process.exit OS.Process.success;\n")
        def again(after, only=""):
            return run(["sh", "-c", '"$0" -q < "$1"', BIN[host], use], cwd=workdir, timeout=TIMEOUT,
                       env=env_after(after, only))[1]
        raw = again("")
        built = not re.search(r"\.sml:\d+: error|Static Errors", raw)
        return built, raw, raw if not built else "", again
    raise SystemExit("unknown host " + host)


def finish(output, again):
    """the output of a program run to its end: where it stopped in a law (a
    crash, or the time it was given), that law is STOPPED and the program
    runs again after it; (the output, the stopped laws)"""
    outputs, stopped = [output], []
    for _ in range(50):
        if re.search(r"^laws: ", output, re.M) or again is None:
            break
        started = re.findall(r"^LAW (\S+)", output, re.M)
        if not started:
            break
        stuck = started[-1]
        if re.search(r"^(PASS|FAIL) " + re.escape(stuck) + r"\b", output, re.M) or stuck in [l for l, _ in stopped]:
            break
        tail = [l for l in output.strip().split("\n") if l.strip()][-1:]
        why = tail[0].strip()[:160] if tail and not tail[0].startswith("LAW ") else "it stopped"
        stopped.append((stuck, why))
        output = again(stuck)
        outputs.append(output)
    return "\n".join(outputs), stopped


def error_lines(host, msgs, source_file):
    """the lines of a program, or of a file of the library, that the build's
    errors point to"""
    base = r"(?<![\w.-])" + re.escape(os.path.basename(source_file))
    pats = {"mlton": base + r" (\d+)\.\d+", "smlnj": base + r":(\d+)\.\d+", "polyml": base + r":(\d+): error",
            "mlkit": base + r", line (\d+)"}
    key = "smlnj" if host.startswith("smlnj") else host
    return {int(m.group(1)) for m in re.finditer(pats[key], msgs)}


def first_error(msgs):
    """the first error of a build, on one line"""
    lines = msgs.split("\n")
    for i, l in enumerate(lines):
        if re.search(r"Error|error:|, line \d+, column \d+:", l):
            return " ".join(x.strip() for x in lines[i:i + 4] if x.strip())[:240]
    return msgs.strip().split("\n")[-1][:240] if msgs.strip() else "(no message)"


def verdicts(output):
    """label -> (PASS or FAIL, the line)"""
    v = {}
    for l in output.split("\n"):
        m = re.match(r"(PASS|FAIL) (\S+?):? ", l)
        if m:
            v[m.group(2)] = (m.group(1), l.strip())
    return v


def deviations():
    """the lines of the deviations: (config glob, label glob, category, reason)"""
    lines = []
    if os.path.exists(DEVIATIONS):
        for l in open(DEVIATIONS):
            if l.strip() and not l.startswith("#"):
                c, label, cat, why = [x.strip() for x in l.split("|", 3)]
                lines.append((c, label, cat, why))
    return lines


def listed(label):
    """whether law-skips.txt lists the law: Rune's failure of it is known"""
    if not os.path.exists(SKIPS):
        return False
    for l in open(SKIPS):
        if l.strip() and not l.startswith("#") and fnmatch.fnmatchcase(label, l.split("|")[0].strip()):
            return True
    return False


def compare(host, lines_out, rune, devs):
    """the differences from Rune of a host's results: explained by a line of
    the deviations, or not; a law Rune fails and law-skips.txt lists is no
    difference where the host passes it"""
    explained, unexplained = [], []
    for label, (v, line) in sorted(verdicts("\n".join(lines_out)).items()):
        if label not in rune or rune[label][0] == v:
            continue
        if rune[label][0] == "FAIL" and v == "PASS" and listed(label):
            continue
        why = next(("%s: %s" % (cat, w) for c, l, cat, w in devs
                    if fnmatch.fnmatchcase("native:" + host, c) and fnmatch.fnmatchcase(label, l)), None)
        text = "%s %s: Rune %s, %s %s\n    Rune: %s\n    %s: %s" % (host, label, rune[label][0], host, v,
                                                                       rune[label][1], host, line)
        (explained if why else unexplained).append(text + ("\n    explained: " + why if why else ""))
    return explained, unexplained


def main():
    if sys.argv[1:2] == ["--compare"]:
        # judge the results already in tests/out/laws-hosts again, as after a
        # change to the deviations
        hosts = [h for h in sys.argv[2:] or BIN if os.path.exists(os.path.join(OUT, h + ".results"))]
        rune = verdicts(open(RESULTS).read()) if os.path.exists(RESULTS) else {}
        devs, total = deviations(), 0
        for host in hosts:
            lines_out = open(os.path.join(OUT, host + ".results")).read().strip().split("\n")
            explained, unexplained = compare(host, lines_out, rune, devs)
            open(os.path.join(OUT, host + ".differences"), "w").write("\n".join(explained + unexplained) + "\n")
            print("%s: %d differences from Rune explained, %d not" % (host, len(explained), len(unexplained)))
            for u in unexplained:
                print(u)
            total += len(unexplained)
        print("test-laws-hosts: %d differences from Rune that no deviation explains" % total)
        sys.exit(1 if total else 0)
    hosts = sys.argv[1:] or ["mlton", "smlnj-legacy", "smlnj32", "smlnj-dev", "polyml", "mlkit"]
    subprocess.run(["rm", "-rf", OUT])
    os.makedirs(OUT + "/programs")
    st, log = run([RUNEDOC, "--lib", "lib", "--library", "basis", "--laws", OUT + "/programs"])
    if st != 0:
        raise SystemExit("test-laws-hosts: runedoc --laws failed:\n" + log)
    programs, alternatives = {}, {}
    for f in sorted(os.listdir(OUT + "/programs")):
        if f.endswith(".sml") and re.search(PROGRAMS, f[:-4]):
            programs[f[:-4]] = split_program(open(os.path.join(OUT, "programs", f)).read())
    # the alternative entries of a law: its types drawn by the arbitraries of
    # its structure's own family, for a host that tells apart types that
    # Rune's are one of (Real64Vector's and RealVector's vectors on MLton)
    for f in sorted(os.listdir(OUT + "/programs")):
        if f.endswith(".alt") and f[:-4] in programs:
            for label, body in split_program(open(os.path.join(OUT, "programs", f)).read())[1]:
                alternatives.setdefault(label, []).append(body)
    files = manifest()
    lib_names = library_names(files)
    wanted, pairs = set(), set()
    for _, entries, _ in programs.values():
        for label, body in entries:
            for b in [body] + alternatives.get(label, []):
                wanted.update(names_in(b))
                pairs.update(opened(b))
            wanted.add(label.split("@", 1)[1])
    for _, _, _, requires in files:
        wanted.update(requires)
    basis_names = {p for n in wanted for p in prefixes(n) if p.split(".")[0] not in lib_names}
    rune = {}
    if os.path.exists(RESULTS):
        rune = verdicts(open(RESULTS).read())
    devs = deviations()
    def one(host):
        if not os.path.exists(BIN[host]):
            return host, "%s: not installed (%s; make hosts)" % (host, BIN[host]), []
        workdir = os.path.join(OUT, host)
        os.makedirs(workdir)
        missing = missing_on(host, basis_names, workdir)
        # a path the host lacks at the top may be under a structure that an
        # entry opens: `StreamIO` under `open BinIO`
        under = {p for o, n in pairs if any(q in missing for q in prefixes(n))
                 for p in prefixes(o + "." + n) if p.split(".")[0] not in lib_names} - basis_names
        missing |= missing_on(host, under, workdir)
        open(os.path.join(OUT, host + ".structures"), "w").write("".join(n + "\n" for n in sorted(missing)))
        present = basis_names - missing
        chosen, provided, dropped = library_on(host, files, present, workdir)
        open(os.path.join(OUT, host + ".library"), "w").write(
            "".join(f + "\n" for f in chosen) + "".join("left out: %s\n" % f for f in sorted(dropped)))
        def lacks(n):
            return [p for p in prefixes(n) if (p in lib_names and p not in provided) or
                    (p.split(".")[0] not in lib_names and p in missing)]
        def lack_of(label, body):
            """what the host lacks of what an entry names: a path is there at
            the top or under a structure the entry opens"""
            return sorted({p for n in names_in(body) | {label.split("@", 1)[1]}
                           if not any(not lacks(o + "." + n) for o in opens_in(body) if o != n)
                           for p in lacks(n)})
        lines_out, on_alternative = [], []
        for prog, (head, entries, tail) in programs.items():
            # each law's entry, then its alternative: the host's own program
            # takes the first that the host has what it names of, and the
            # next where it does not build
            keep, notbuilt = [], []
            for label, body in entries:
                choices = [b for b in [body] + alternatives.get(label, []) if not lack_of(label, b)]
                if choices:
                    keep.append((label, choices[0], choices[1:]))
                else:
                    notbuilt.append((label, "the host lacks " + ", ".join(lack_of(label, body))))
            primary = dict(entries)
            output, stopped, rerun = "", [], None
            for attempt in range(ATTEMPTS):
                if not keep:
                    break
                text = head + "\n" + ",\n".join(b for _, b, _ in keep) + tail
                pfile = os.path.join(workdir, prog + ".sml")
                open(pfile, "w").write(text)
                built, output, msgs, again = build(host, prog, RANDOM + chosen + [pfile], workdir)
                open(os.path.join(workdir, prog + ".build"), "w").write(msgs)
                if built:
                    output, stopped = finish(output, again)
                    rerun = again
                    break
                bad = error_lines(host, msgs, pfile)
                # the entries the errors are in
                starts, at = [], len(head.split("\n"))
                for label, body, _ in keep:
                    starts.append((at + 1, at + len(body.split("\n")), label))
                    at += len(body.split("\n"))
                hit = {label for lo, hi, label in starts for b in bad if lo <= b <= hi}
                why = first_error(msgs)
                if not hit:
                    notbuilt += [(label, "the program does not build: " + why) for label, _, _ in keep]
                    keep = []
                    break
                # an entry the errors are in takes its next choice, or is not built
                notbuilt += [(l, why) for l, _, rest in keep if l in hit and not rest]
                keep = [(l, rest[0], rest[1:]) if l in hit else (l, b, rest) for l, b, rest in keep if l not in hit or rest]
            else:
                if keep:
                    notbuilt += [(label, "the program does not build after %d attempts: %s" % (ATTEMPTS, why))
                                 for label, _, _ in keep]
                    keep = []
            open(os.path.join(workdir, prog + ".out"), "w").write(output)
            got = verdicts(output)
            halted = dict(stopped)
            on_alternative += [label for label, b, _ in keep if b != primary[label]]
            for label, _, _ in keep:
                if label in got and got[label][0] == "FAIL" and rerun is not None:
                    # by itself, three times at most where the host stops
                    # before a verdict (SML/NJ's "bogus fault")
                    second = None
                    for _ in range(3):
                        second = verdicts(rerun("", label)).get(label)
                        if second is not None:
                            break
                    if second is not None and second[1] != got[label][1]:
                        lines_out.append("FLAKY %s: %s; again: %s" % (label, got[label][1], second[1]))
                        continue
                    if second is None:
                        lines_out.append("%s; again: the program stopped before a verdict, three times" % got[label][1])
                        continue
                if label in got:
                    lines_out.append(got[label][1])
                elif label in halted:
                    lines_out.append("STOPPED %s: %s" % (label, halted[label]))
                else:
                    lines_out.append("NOT RUN %s: the program stopped before it" % label)
            lines_out += ["NOT BUILT %s: %s" % (l, w) for l, w in notbuilt]
        open(os.path.join(OUT, host + ".results"), "w").write("\n".join(lines_out) + "\n")
        open(os.path.join(OUT, host + ".alternatives"), "w").write("".join(l + "\n" for l in on_alternative))
        explained, diffs = compare(host, lines_out, rune, devs)
        open(os.path.join(OUT, host + ".differences"), "w").write("\n".join(explained + diffs) + "\n")
        counts = {k: sum(1 for l in lines_out if l.startswith(k))
                  for k in ("PASS", "FAIL", "FLAKY", "STOPPED", "NOT BUILT", "NOT RUN")}
        return host, ("%s: %d laws pass, %d fail, %d flaky, %d stopped, %d not built, %d not run (%d by their "
                      "alternative entries); %d differ from Rune and are explained, %d are not"
                      % (host, counts["PASS"], counts["FAIL"], counts["FLAKY"], counts["STOPPED"], counts["NOT BUILT"],
                         counts["NOT RUN"], len(on_alternative), len(explained), len(diffs))), diffs

    differences = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(JOBS, len(hosts))) as pool:
        for host, summary, diffs in pool.map(one, hosts):
            print(summary, flush=True)
            differences += diffs
    open(os.path.join(OUT, "differences.txt"), "w").write("\n".join(differences) + ("\n" if differences else ""))
    print("test-laws-hosts: %d differences from Rune that no deviation explains (see %s/differences.txt)" %
          (len(differences), OUT))
    sys.exit(1 if differences else 0)


if __name__ == "__main__":
    main()
