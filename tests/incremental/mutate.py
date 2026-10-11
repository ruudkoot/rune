#!/usr/bin/env python3
"""The cache against compiling everything, on edits nobody wrote by hand
(docs/plans/build-cache-issues.md, issue 5).

    mutate.py [--rune BIN] [--out DIR] [--flags F] [--steps N] [--seed S] PROJECT...
    mutate.py [--rune BIN] [--out DIR] [--flags F] --history N [--repo DIR]

A PROJECT is a directory of SML files with `files`, their order, or
`compiler`, the compiler's own sources as `make` lists them. Each step
edits the project as a person might -- a fixity directive's precedence or
side, two constructors of a datatype swapped, a numeral changed, a value
added at top level or inside a structure, a type abbreviation or an
exception's argument changed (in other words or in meaning), an earlier
file declared again later in the order, two files swapped, a file removed
or renamed, a comment added, a file put back as it was -- and builds it in units through one cache (rune --units
--cache-dir) and without it (--no-cache). The two must agree: both fail,
or both succeed and are the same bytes. Most edits leave a program that
compiles; those that do not still check that the cache does not make a
program where compiling everything makes none.

--flags gives both builds more options (`--flags=-O2`). --basis NAME,...
gives each project a copy of the Basis Library of its own, whose files of
those names the edits change too: the library edited under a kept cache.

--history N replays the last N commits of the repository (this one unless
--repo names another): each commit's compiler sources, built through one
cache after the commit before's, against the same without it.

A disagreement is kept in DIR/failure-K (the project as it was, the edits
that led to it, both builds' messages) and makes the exit status 1."""
import argparse
import os
import random
import re
import shutil
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

KEYWORDS = r'(?:val|fun|type|datatype|exception|structure|end|and|local|in|open|infix|infixr|nonfix|' \
           r'signature|functor|withtype|abstype|eqtype|include|sharing|let)'


def run_rune(rune, cwd, files, flags):
    p = subprocess.run([rune, '--units'] + flags + files + ['-o', 'p.rbc'], cwd=cwd,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = os.path.join(cwd, 'p.rbc')
    data = open(out, 'rb').read() if p.returncode == 0 and os.path.exists(out) else None
    if os.path.exists(out):
        os.remove(out)
    return p.returncode, data, p.stderr.decode(errors='replace')


class Project:
    def __init__(self, src, work, files, basis=()):
        self.work = work
        self.files = list(files)
        # the Basis files that may be edited, in the project's own copy of
        # the library (lib/basis/NAME), which builds name with --lib
        self.basis = ['lib/basis/' + b for b in basis]
        self.original = {f: open(os.path.join(src, f), encoding='latin-1').read() for f in files}
        self.text = dict(self.original)
        self.counter = 0
        if os.path.exists(work):
            shutil.rmtree(work)
        for f, t in self.text.items():
            self.write(f, t)
        if self.basis:
            shutil.copytree(os.path.join(ROOT, 'lib', 'basis'), os.path.join(work, 'lib', 'basis'))
            for b in self.basis:
                self.original[b] = self.text[b] = open(os.path.join(work, b), encoding='latin-1').read()

    def editable(self):
        return self.files + self.basis

    def flags(self):
        return ['--lib', os.path.join(self.work, 'lib')] if self.basis else []

    def write(self, f, t):
        p = os.path.join(self.work, f)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='latin-1') as out:
            out.write(t)
        self.text[f] = t

    def fresh(self):
        self.counter += 1
        return self.counter


# ---- the edits: each returns a description, or None where it does not apply ----

def edit_fixity(pr, rng):
    cands = [(f, m) for f in pr.editable() for m in re.finditer(r'\b(infixr?)\s+(\d)\b', pr.text[f])]
    if not cands:
        return None
    f, m = rng.choice(cands)
    t = pr.text[f]
    if rng.random() < 0.5:
        new = '%s %d' % (m.group(1), (int(m.group(2)) + rng.randint(1, 9)) % 10)
    else:
        new = '%s %s' % ('infix' if m.group(1) == 'infixr' else 'infixr', m.group(2))
    pr.write(f, t[:m.start()] + new + t[m.end():])
    return 'fixity in %s: %r -> %r' % (f, m.group(0), new)


def alternatives(t, start):
    """The constructors of a datatype whose `=` ends at start: their spans,
    split at `|` outside brackets, to the next declaration's keyword"""
    depth, i, spans, s = 0, start, [], start
    n = len(t)
    while i < n:
        c = t[i]
        if t.startswith('(*', i) or c == '"':
            return None
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth < 0:
                break
        elif depth == 0 and c == '|':
            spans.append((s, i))
            s = i + 1
        elif depth == 0 and (c == ';' or (c.isalpha() and (i == 0 or not (t[i - 1].isalnum() or t[i - 1] in "_'."))
                                         and re.match(KEYWORDS + r'\b', t[i:]))):
            break
        i += 1
    spans.append((s, i))
    return spans if len(spans) >= 2 else None


def edit_constructors(pr, rng):
    cands = []
    for f in pr.editable():
        t = pr.text[f]
        for m in re.finditer(r'\bdatatype\s+(?:\([^)]*\)\s*|\'\w+\s+)?[\w\']+\s*=(?!\s*datatype)', t):
            spans = alternatives(t, m.end())
            if spans:
                cands.append((f, spans))
    if not cands:
        return None
    f, spans = rng.choice(cands)
    t = pr.text[f]
    a, b = sorted(rng.sample(range(len(spans)), 2))
    (s1, e1), (s2, e2) = spans[a], spans[b]
    x, y = t[s1:e1].strip(), t[s2:e2].strip()
    new = t[:s1] + ' ' + y + ' ' + t[e1:s2] + ' ' + x + ' ' + t[e2:]
    pr.write(f, new)
    return 'constructors in %s: %r and %r swapped' % (f, x.split()[0], y.split()[0])


def code_spans(t):
    """The parts of a text outside comments and strings, roughly"""
    spans, i, s, n = [], 0, 0, len(t)
    while i < n:
        if t.startswith('(*', i):
            spans.append((s, i))
            depth = 1
            i += 2
            while i < n and depth:
                if t.startswith('(*', i):
                    depth += 1
                    i += 2
                elif t.startswith('*)', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            s = i
        elif t[i] == '"':
            spans.append((s, i))
            i += 1
            while i < n and t[i] != '"':
                i += 2 if t[i] == '\\' else 1
            i += 1
            s = i
        else:
            i += 1
    spans.append((s, n))
    return spans


def edit_numeral(pr, rng):
    cands = []
    for f in pr.editable():
        t = pr.text[f]
        for s, e in code_spans(t):
            for m in re.finditer(r'(?<![\w\'#.~])(\d+)(?![\w.])', t[s:e]):
                cands.append((f, s + m.start(1), s + m.end(1)))
    if not cands:
        return None
    f, s, e = rng.choice(cands)
    t = pr.text[f]
    old = t[s:e]
    new = str(int(old) + rng.choice([1, 2, 7]))
    pr.write(f, t[:s] + new + t[e:])
    return 'numeral in %s: %s -> %s' % (f, old, new)


def edit_top_value(pr, rng):
    f = rng.choice(pr.editable())
    k = pr.fresh()
    pr.write(f, pr.text[f] + '\nval runeMutant%d = %d\n' % (k, k))
    return 'value runeMutant%d added at the end of %s' % (k, f)


def edit_struct_value(pr, rng):
    cands = []
    for f in pr.editable():
        t = pr.text[f]
        for s, e in code_spans(t):
            for m in re.finditer(r'\bstruct\b', t[s:e]):
                cands.append((f, s + m.end()))
    if not cands:
        return None
    f, at = rng.choice(cands)
    k = pr.fresh()
    t = pr.text[f]
    pr.write(f, t[:at] + ' val runeMutant%d = %d ' % (k, k) + t[at:])
    return 'value runeMutant%d added inside a structure of %s' % (k, f)


def edit_comment(pr, rng):
    f = rng.choice(pr.editable())
    k = pr.fresh()
    pr.write(f, pr.text[f] + '\n(* mutant %d *)\n' % k)
    return 'comment added to %s' % f


def edit_shadow(pr, rng):
    if len(pr.files) < 2:
        return None
    i = rng.randrange(len(pr.files) - 1)
    j = rng.randrange(i + 1, len(pr.files) + 1)
    f = pr.files[i]
    k = pr.fresh()
    g = os.path.join(os.path.dirname(f), 'again%d_%s' % (k, os.path.basename(f)))
    pr.write(g, pr.text[f])
    pr.files.insert(j, g)
    return '%s declared again as %s, at %d of %d' % (f, g, j, len(pr.files))


def edit_swap(pr, rng):
    if len(pr.files) < 2:
        return None
    i = rng.randrange(len(pr.files) - 1)
    pr.files[i], pr.files[i + 1] = pr.files[i + 1], pr.files[i]
    return '%s and %s swapped' % (pr.files[i + 1], pr.files[i])


def edit_revert(pr, rng):
    changed = [f for f in pr.editable() if f in pr.original and pr.text[f] != pr.original[f]]
    extra = [f for f in pr.files if f not in pr.original]
    missing = [f for f in pr.original if f not in pr.files]
    if rng.random() < 0.3 and (extra or changed or missing):
        pr.files = [f for f in pr.original if f not in pr.basis]
        for f in pr.original:
            if pr.text[f] != pr.original[f]:
                pr.write(f, pr.original[f])
        return 'the whole project put back'
    if not changed:
        return None
    f = rng.choice(changed)
    pr.write(f, pr.original[f])
    return '%s put back' % f


def edit_type(pr, rng):
    """A type abbreviation's body: the same type in other words, or another"""
    cands = []
    for f in pr.editable():
        t = pr.text[f]
        for s, e in code_spans(t):
            for m in re.finditer(r'\btype\s+(?:\([^)]*\)\s*|\'\w+\s+)?[\w\']+\s*=\s*([^\n=]+?)\s*(?=\n|\band\b|\bend\b|\bval\b|\bfun\b|\btype\b|\bdatatype\b|$)',
                                 t[s:e]):
                if 'datatype' not in m.group(0):
                    cands.append((f, s + m.start(1), s + m.end(1)))
    if not cands:
        return None
    f, a, b = rng.choice(cands)
    t = pr.text[f]
    body = t[a:b]
    if body.strip() == 'int' and rng.random() < 0.5:
        new = 'IntInf.int'
    elif rng.random() < 0.5:
        new = '(' + body + ')'
    else:
        new = body + ' * unit'
    pr.write(f, t[:a] + new + t[b:])
    return 'type in %s: %r -> %r' % (f, body, new)


def edit_exception(pr, rng):
    """An exception's argument: added, wrapped, or made a pair"""
    cands = []
    for f in pr.editable():
        t = pr.text[f]
        for s, e in code_spans(t):
            for m in re.finditer(r'\bexception\s+([\w\']+)(\s+of\s+[^\n]+?)?(?=\s*(?:\n|\band\b|\bend\b|\bval\b|\bfun\b|$))',
                                 t[s:e]):
                if '=' not in m.group(0):
                    cands.append((f, s + m.start(), s + m.end(), m.group(1), m.group(2)))
    if not cands:
        return None
    f, a, b, name, arg = rng.choice(cands)
    t = pr.text[f]
    if arg is None:
        new = 'exception %s of int' % name
    elif rng.random() < 0.5:
        new = 'exception %s of (%s)' % (name, arg.split(None, 1)[1])
    else:
        new = 'exception %s of %s * unit' % (name, arg.split(None, 1)[1])
    pr.write(f, t[:a] + new + t[b:])
    return 'exception in %s: %r -> %r' % (f, t[a:b], new)


def edit_remove(pr, rng):
    if len(pr.files) < 2:
        return None
    f = rng.choice(pr.files)
    pr.files.remove(f)
    return '%s removed from the order' % f


def edit_rename(pr, rng):
    f = rng.choice(pr.files)
    k = pr.fresh()
    g = os.path.join(os.path.dirname(f), 'renamed%d_%s' % (k, os.path.basename(f)))
    pr.write(g, pr.text[f])
    pr.files[pr.files.index(f)] = g
    return '%s renamed %s' % (f, g)


EDITS = [(edit_fixity, 3), (edit_constructors, 4), (edit_numeral, 5), (edit_top_value, 2),
         (edit_struct_value, 3), (edit_comment, 1), (edit_shadow, 2), (edit_swap, 1), (edit_revert, 4),
         (edit_type, 3), (edit_exception, 2), (edit_remove, 1), (edit_rename, 1)]


def sources_of(tree):
    """The compiler's sources in a tree: its rune.build's files, or, before
    there were build files, its sources.txt"""
    if os.path.exists(os.path.join(tree, 'rune.build')):
        p = subprocess.run(['sh', os.path.join(ROOT, 'scripts', 'build-files.sh'), os.path.join(tree, 'rune.build')],
                           stdout=subprocess.PIPE, check=True)
        return p.stdout.decode().split()
    with open(os.path.join(tree, 'sources.txt')) as f:
        return [l.strip() for l in f if l.strip() and not l.strip().startswith('#')]


def compiler_project():
    return ROOT, ['build/config.sml'] + sources_of(ROOT) + ['src/main/rune-main.sml']


class Checker:
    def __init__(self, rune, out, flags):
        self.rune, self.out, self.flags, self.failures, self.builds, self.compiled = rune, out, flags, 0, 0, 0
        # units taken from the cache across a unit that changed (M6's third part)
        self.across = 0

    def check(self, pr, history):
        cache = os.path.join(self.out, 'cache')
        flags = self.flags + pr.flags()
        st1, b1, e1 = run_rune(self.rune, pr.work, pr.files, flags + ['--cache-dir', cache, '--explain-rebuild'])
        st2, b2, e2 = run_rune(self.rune, pr.work, pr.files, flags + ['--no-cache'])
        self.builds += 1
        self.compiled += len([l for l in e1.splitlines() if l.startswith('rune: compiled ') and 'lib/basis' not in l])
        self.across += len([l for l in e1.splitlines() if l.startswith('rune: from the cache ') and ', across ' in l])
        ok = (st1 == 0) == (st2 == 0) and (st1 != 0 or b1 == b2)
        if not ok:
            self.failures += 1
            d = os.path.join(self.out, 'failure-%d' % self.failures)
            shutil.copytree(pr.work, d)
            with open(os.path.join(d, 'files'), 'w') as f:
                f.write('\n'.join(pr.files) + '\n')
            with open(os.path.join(d, 'history'), 'w') as f:
                f.write('\n'.join(history) + '\n')
            with open(os.path.join(d, 'cached.err'), 'w') as f:
                f.write(e1)
            with open(os.path.join(d, 'nocache.err'), 'w') as f:
                f.write(e2)
            why = ('other bytes' if st1 == 0 and st2 == 0 else
                   'the cache built it and compiling everything did not' if st1 == 0 else
                   'compiling everything built it and the cache did not')
            print('FAIL mutate: %s, after %s (%s)' % (why, history[-1], d), flush=True)
        return ok, st2 == 0


def mutations(args, checker, rng):
    for spec in args.projects:
        if spec == 'compiler':
            src, files = compiler_project()
            name = 'compiler'
        else:
            src = os.path.abspath(spec)
            files = open(os.path.join(src, 'files')).read().split()
            name = os.path.basename(src.rstrip('/'))
        pr = Project(src, os.path.join(args.out, 'work-' + name), files,
                     [b for b in args.basis.split(',') if b])
        history = ['the project as it is']
        ok, built = checker.check(pr, history)
        counts, builtn = {}, 0
        for step in range(args.steps):
            edits = [e for e, w in EDITS for _ in range(w)]
            what = None
            while what is None:
                edit = rng.choice(edits)
                what = edit(pr, rng)
            history.append(what)
            ok, built = checker.check(pr, history)
            kind = edit.__name__[len('edit_'):]
            counts[kind] = counts.get(kind, 0) + 1
            builtn += built
            if not built and rng.random() < 0.5:
                # back towards a program that compiles
                history.append(edit_revert(pr, rng) or 'nothing to put back')
                checker.check(pr, history)
        print('mutate %s: %d steps, %d of them a program; edits %s' %
              (name, args.steps, builtn, ', '.join('%s %d' % kv for kv in sorted(counts.items()))), flush=True)


def replay(args, checker):
    repo = os.path.abspath(args.repo or ROOT)
    commits = subprocess.run(['git', '-C', repo, 'rev-list', '--first-parent', '-n', str(args.history), 'HEAD'],
                             stdout=subprocess.PIPE, check=True).stdout.decode().split()[::-1]
    work = os.path.join(args.out, 'work-history')
    for c in commits:
        tree = os.path.join(args.out, 'tree')
        if os.path.exists(tree):
            shutil.rmtree(tree)
        os.makedirs(tree)
        archive = subprocess.run(['git', '-C', repo, 'archive', c], stdout=subprocess.PIPE, check=True).stdout
        subprocess.run(['tar', '-x', '-C', tree], input=archive, check=True)
        g = subprocess.run(['sh', 'scripts/gen-build-files.sh'], cwd=tree, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
        if g.returncode != 0 or not os.path.exists(os.path.join(tree, 'build', 'config.sml')):
            print('mutate history: %s skipped, its build files could not be made' % c[:10], flush=True)
            continue
        files = ['build/config.sml'] + sources_of(tree) + ['src/main/rune-main.sml']
        missing = [f for f in files if not os.path.exists(os.path.join(tree, f))]
        if missing:
            # a file `make` generated then, which the commit does not hold
            print('mutate history: %s skipped, it does not hold %s' % (c[:10], missing[0]), flush=True)
            continue
        # the work directory keeps its path, so that names in the cache are the same
        if os.path.exists(work):
            shutil.rmtree(work)
        os.makedirs(work)
        for f in files:
            os.makedirs(os.path.dirname(os.path.join(work, f)), exist_ok=True)
            shutil.copy(os.path.join(tree, f), os.path.join(work, f))
        pr = Project.__new__(Project)
        pr.work, pr.files, pr.text, pr.original, pr.counter, pr.basis = work, files, {}, {}, 0, []
        before = checker.compiled
        ok, built = checker.check(pr, ['commit ' + c])
        print('mutate history: %s %s, %d units compiled' %
              (c[:10], 'a program' if built else 'no program', checker.compiled - before), flush=True)


def main():
    ap = argparse.ArgumentParser(usage=__doc__)
    ap.add_argument('--rune', default=os.path.join(ROOT, 'bin', 'rune'))
    ap.add_argument('--out', default=os.path.join(ROOT, 'tests', 'out', 'mutate'))
    ap.add_argument('--steps', type=int, default=50)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--history', type=int, default=0)
    ap.add_argument('--repo')
    ap.add_argument('--flags', default='')
    ap.add_argument('--basis', default='')
    ap.add_argument('projects', nargs='*')
    args = ap.parse_args()
    args.rune = os.path.abspath(args.rune)
    args.out = os.path.abspath(args.out)
    if os.path.exists(args.out):
        shutil.rmtree(args.out)
    os.makedirs(args.out)
    checker = Checker(args.rune, args.out, args.flags.split())
    if args.history:
        replay(args, checker)
    mutations(args, checker, random.Random(args.seed))
    print('mutate: %d builds, %d disagreements; %d units taken from the cache across a unit that changed'
          % (checker.builds, checker.failures, checker.across), flush=True)
    sys.exit(1 if checker.failures else 0)


if __name__ == '__main__':
    main()
