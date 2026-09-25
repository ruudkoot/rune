# Setting up a cloud session

A cloud coding environment starts from a fresh machine every session,
without the system packages that Rune's tooling needs. On Claude Code on the
web the session-start hook (`.claude/hooks/session-start.sh`) does the steps
below before the session begins, and says in
`/tmp/rune-session-start.status` what it did and what is still missing; the packages it installs are the ones listed here, which the user
agreed to by adding the hook. Where there is no hook, or it reports a
problem, do them by hand before building or testing anything:

1. **Run `make doctor`.** It lists every missing item, with the packages that
   provide it.
2. **Ask the user before installing packages.** Show them what `make doctor`
   reported and the commands below, and install only once they agree.
3. **Run `make hosts`** once the packages are in, which fetches and builds
   MLton, SML/NJ (64 and 32 bits) and Poly/ML under `~/.local/rune-hosts`.
   `make doctor` should then pass.
4. **Run `make envcheck`** (under a minute, `docs/envcheck.md`): it reports
   what the machine is and how fast, and says whether `cloud/ENVIRONMENT.md`
   describes this kind of machine. If not, add an entry there
   (`make envcheck ENVCHECK=--markdown` prints one to start from). If it
   reports that it could not do everything, make it work here and commit
   the fix.

Before the first commit, check that `git var GIT_AUTHOR_IDENT` names
`Ruud Koot <inbox@ruudkoot.nl>` and `git var GIT_COMMITTER_IDENT`
`Claude <noreply@anthropic.com>` (`AGENTS.md`).

The sections up to *Claude Code on the web* hold for any cloud machine
running Ubuntu; that one is about what only Anthropic's cloud sessions do.

## Packages (Ubuntu 24.04, as of 2026-09-25)

Required by `make hosts`:

    apt-get install -y libgmp-dev gcc-multilib

Optional (the debug-information checks of the native code generator):

    apt-get install -y dwarfdump linux-tools-generic

`perf` comes with the `linux-tools` package of the running kernel. A
kernel that Ubuntu has no such package for (the Firecracker kernel of
Claude Code on the web, `6.18.44-fc`, or WSL2's `-microsoft-standard-WSL2`)
gets Ubuntu's `/usr/bin/perf` wrapper, which refuses to run under it;
`make doctor` warns and names the fix. The binary of `linux-tools-generic`
works, so put it first on the PATH:

    ln -sf /usr/lib/linux-tools/*/perf /usr/local/bin/perf

Inside a VM `perf` may have no hardware counters (`cloud/ENVIRONMENT.md`).

## Optional tools

Once the main check passes, `make doctor` goes on to the Windows toolchain
and the portability tools (`sh scripts/doctor.sh --scope windows` or
`--scope portability` checks either alone). Those are optional: `make
windows` and `make portability` and their tests need them (see `AGENTS.md`).

    apt-get install -y gcc-mingw-w64-x86-64 gcc-mingw-w64-i686 \
      libc6-dev-ppc64-cross binutils-powerpc64-linux-gnu \
      libgcc-13-dev-ppc64-cross qemu-user

`libgcc-13-dev-ppc64-cross` (13 is the version of `gcc`) is there for clang,
which finds the crt files and `libgcc` of the PowerPC sysroot only through a
GCC cross installation; without it the check fails with `cannot find
Scrt1.o` (`make doctor` names the package). Do not install
`gcc-powerpc64-linux-gnu` for it: that compiler conflicts with
`gcc-multilib`, and apt removes whichever of the two came first. `-m32`
keeps working without `gcc-multilib` itself, but the package list no longer
says so, and installing it again takes the cross compiler away. Then all
three scopes are ready, except that Windows `.exe`s cannot run on a Linux
machine: `make windows` and `make portability` work, but `make test-windows`
needs Windows or WSL.

## Claude Code on the web

What follows is specific to Claude Code on the web (claude.ai/code),
Anthropic's managed cloud sessions, which a session recognises by
`CLAUDE_CODE_REMOTE=true`. Such a session runs in a Firecracker microVM
(`cloud/ENVIRONMENT.md`), reaches GitHub only through the repositories
attached to it, and has its settings (environment variables, setup script)
in the environment's configuration on claude.ai, which only the user can
change.

### Commit author

Commits are authored by Ruud Koot and committed by Claude: the session
signs a commit only when its committer is `noreply@anthropic.com`, and
GitHub shows the others as unverified. The session writes
`/root/.gitconfig` with `Claude <noreply@anthropic.com>` when the container
starts, and again when it restarts during a session, so a `git config` made
earlier can be gone by the next commit; the hook sets the two again:

    git config --global author.name "Ruud Koot"
    git config --global author.email inbox@ruudkoot.nl
    git config --global committer.name Claude
    git config --global committer.email noreply@anthropic.com

The environment's variables `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL` (Ruud
Koot), and `GIT_COMMITTER_NAME` and `GIT_COMMITTER_EMAIL` (Claude), would
take precedence over that file and survive a restart.

### The session-start hook

`.claude/hooks/session-start.sh`, registered in `.claude/settings.json`,
runs when a session starts or resumes, only where `CLAUDE_CODE_REMOTE=true`.
It sets the commit author, installs the packages above that are missing,
links a `perf` that runs, runs `make hosts` and `make doctor`, and at the
start of a session `make envcheck`.

It is synchronous: the session begins once it is done, and what it prints
is the first thing the session sees. It also keeps its state in
`/tmp/rune-session-start.status`:

* `running (since ...)`: it is not done (a setup script, below, still
  running);
* `ready (...)`: the machine is ready; the lines after it say what the hook
  did, the machine's fingerprint and whether `cloud/ENVIRONMENT.md` knows
  it;
* `problems (...)`: something failed; the lines after it say what, and the
  full output is in `/tmp/rune-session-start.log` (and `make envcheck`'s in
  `/tmp/rune-envcheck.txt`).

No file at all means the hook did not run: do the steps above by hand.

**Several repositories in one environment:** Claude Code then reads the
settings of none of them, and the hook does not run. The environment's
setup script (its settings on claude.ai, under *Setup script*) can run it
instead:

```bash
#!/bin/bash
# Rune: prepare the machine as its session-start hook does (cloud/SETUP.md)
repo=/home/user/rune
if [ ! -f "$repo/.claude/hooks/session-start.sh" ]; then
  repo=$(find /home /workspace -maxdepth 4 -path '*/.claude/hooks/session-start.sh' 2>/dev/null |
         while read -r f; do d=${f%/.claude/hooks/session-start.sh}; [ -f "$d/scripts/cloud-cache.sh" ] && echo "$d"; done | head -1)
fi
if [ -n "$repo" ]; then
  echo '{"source":"startup"}' |
    CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$repo" bash "$repo/.claude/hooks/session-start.sh"
else
  echo "rune: no checkout found; the machine is not prepared (cloud/SETUP.md)"
fi
exit 0
```

With everything installed it takes about 30 s at the start of a session
(8.5 s of it `make doctor`, 22 s `make envcheck`) and 7.5 s on resume.

### The cache of the hosts

The host SML systems take 162 s to build on a fresh machine (`make hosts`
builds the four at once; one after another they took about 260 s: MLton 1,
SML/NJ 49 and 53, Poly/ML 157). The branch `cloud-cache` holds them
prebuilt, 66 MB in `cloud/cache/`, and the hook restores them from it in
about 7 s where they are missing (`scripts/cloud-cache.sh restore`): a
hook without the hosts took 16 s in all. The cache carries a key of the
host versions, the architecture, the release of Ubuntu, the version of
glibc and the directory `~/.local/rune-hosts`, since SML/NJ and Poly/ML
keep the directory they were installed in; it is used only where the key
is the machine's, and its SHA-256 is checked. Anywhere else `make hosts`
builds as before.

When the key changes (a new host version in `scripts/fetch-hosts.sh`, or
a new Ubuntu or glibc on the cloud machines), the hook reports nothing
restored and the hosts are built; refresh the cache then with
`scripts/cloud-cache.sh save`, which replaces the branch's one commit with
the installed hosts (after `make hosts` and `make doctor` pass).

### Poly/ML: the archive is blocked

The session's GitHub access covers only the repositories attached to it, so
the download of Poly/ML's archive (`github.com/polyml/polyml/archive/...`)
gets a 403. A `git clone` of a public repository is allowed, and
`scripts/fetch-hosts.sh` then builds Poly/ML from a clone of the release's
tag, which has the same sources. The hosts take about 285 MB.

### What lasts

Packages, the hosts and the build survive a restart of the container
within a session; a new session, or one reclaimed after being idle, starts
from a fresh machine, and only what is pushed carries over.
