#!/usr/bin/env python3
"""Check build packaging and failed compilation in an isolated checkout with spaces."""
from pathlib import Path
import shutil
import tempfile
from test import ROOT, run


def main():
    with tempfile.TemporaryDirectory(prefix="rune build checkout ") as tmp:
        copy = Path(tmp) / "Rune source"
        shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns(".git", "build", ".cm", "__pycache__"))
        for host in ("smlnj", "polyml", "mlton", "mosml"):
            run(["make", f"HOST={host}", "build"], cwd=copy)
            compiler = copy / "build" / host / "rune"
            first = compiler.stat().st_mtime_ns
            run(["make", f"HOST={host}", "build"], cwd=copy)
            assert compiler.stat().st_mtime_ns == first, f"unnecessary rebuild: {host}"
            run([compiler, "-o", "output with spaces.rbc", "examples/hello.sml"], cwd=copy)
            run([copy / "build/vm/rune-vm", "output with spaces.rbc"], cwd=copy, stdout=b"42\n")
            source = copy / "src/main.sml"
            original = source.read_text()
            source.write_text(original + "\nthis is deliberately invalid SML\n")
            run(["make", f"HOST={host}", "compiler"], cwd=copy, status=2)
            source.write_text(original + "\n(* rebuild probe *)\n")
            run(["make", f"HOST={host}", "compiler"], cwd=copy)
            assert compiler.stat().st_mtime_ns != first, f"source change was ignored: {host}"
            source.write_text(original)
            print(f"{host}: spaced checkout, incremental builds, error propagation, and rebuild passed.")


if __name__ == "__main__":
    main()
