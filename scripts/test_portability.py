#!/usr/bin/env python3
"""Build and run the i386/PowerPC64 VM matrix on an x86-64 Linux development host."""
import os
from pathlib import Path
import shlex
import shutil
import struct
import subprocess
import sys

from test import ROOT, run


def tool(variable, default):
    name = os.environ.get(variable) or default
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"missing {variable} tool: {name}; see docs/BUILD.md#portability-checks")
    return str(Path(path).absolute())


def check_elf(path, bits, big_endian, machine):
    with path.open("rb") as stream:
        header = stream.read(20)
    byte_order = 2 if big_endian else 1
    if (len(header) != 20 or header[:4] != b"\x7fELF" or
            header[4] != (1 if bits == 32 else 2) or header[5] != byte_order or
            struct.unpack(">H" if big_endian else "<H", header[18:20])[0] != machine):
        raise RuntimeError(f"wrong ELF architecture, width, or byte order: {path}")


def build_target(name, compiler, flags, emulator, bits, big_endian, machine):
    directory = ROOT / "build" / "portability" / name
    directory.mkdir(parents=True, exist_ok=True)
    common = [compiler, *flags, "-std=c11", "-Wall", "-Wextra", "-Wpedantic", "-Werror", "-O2"]
    for source, filename, extra in (
        ("tests/vm/platform.c", "platform", [f"-DRUNE_EXPECT_POINTER_BITS={bits}",
                                            f"-DRUNE_EXPECT_BIG_ENDIAN={int(big_endian)}"]),
        ("vm/vm.c", "rune-vm", []),
        ("tests/vm/gc.c", "test-gc", []),
    ):
        output = directory / filename
        run([*common, *extra, ROOT / source, "-o", output])
        check_elf(output, bits, big_endian, machine)
    expected = f"pointer bits: {bits}; byte order: {'big' if big_endian else 'little'}\n"
    run([*emulator, directory / "platform"], stdout=expected.encode())
    print(f"{name} (emulated): ELF verified; {expected.strip()}", flush=True)
    result = run([*emulator, directory / "test-gc"])
    print(result.stdout.decode(), end="", flush=True)
    launcher = directory / "run-vm"
    launcher.write_text("#!/bin/sh\nexec " + shlex.join([*emulator, str(directory / "rune-vm")]) + ' "$@"\n')
    launcher.chmod(0o755)
    return launcher


def main():
    # Resolve all tools before building, so missing dependencies fail explicitly.
    i386_cc = tool("I386_CC", "gcc")
    ppc64_cc = tool("PPC64_CC", "clang")
    qemu_i386 = tool("QEMU_I386", "qemu-i386")
    qemu_ppc64 = tool("QEMU_PPC64", "qemu-ppc64")
    sysroot = Path(os.environ.get("PPC64_SYSROOT") or "/usr/powerpc64-linux-gnu").resolve()
    if not (sysroot / "lib" / "ld64.so.1").is_file():
        raise RuntimeError(f"missing PowerPC64 runtime loader in {sysroot}; see docs/BUILD.md#portability-checks")
    native = ROOT / "build" / "vm" / "rune-vm"
    check_elf(native, 64, False, 62)  # ELF EM_X86_64
    i386 = build_target("i386", i386_cc, ["-m32"], [qemu_i386], 32, False, 3)
    ppc64 = build_target("powerpc64", ppc64_cc,
                         ["--target=powerpc64-linux-gnu", "--gcc-toolchain=/usr"],
                         [qemu_ppc64, "-L", str(sysroot)], 64, True, 21)
    # test.py compiles each source once per host and runs those exact bytes on
    # every VM before replacing the file. It also compares runtime diagnostics.
    subprocess.run([sys.executable, "-u", str(ROOT / "scripts" / "test.py"),
                    "--hosts", "smlnj", "polyml", "mlton",
                    "--vm", str(native), "--vm", str(i386), "--vm", str(ppc64)],
                   cwd=ROOT, check=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"portability: {error}")
