#!/usr/bin/env python3
"""Build the Linux and Windows distribution archives.

make dist runs this. The archives hold every library under lib (the files
install.sh installs), the compiler, the REPL image, and the register VM for
each machine, under runtime/<arch>/. bin/rune-scenarios dist checks it with
stand-in binaries (--fixture); a real archive refuses a VM whose ELF or PE
header is not that machine's.
"""
import argparse
import gzip
import io
import re
import struct
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINUX_ARCH = ('x86_64', 'i686', 'aarch64', 'ppc64')
WINDOWS_ARCH = ('x86_64', 'i686')
VERSION_RE = re.compile(r'[A-Za-z0-9._+-]+')

ELFMAG = b'\x7fELF'
PT_LOAD = 1
PT_DYNAMIC = 2
PT_INTERP = 3
DT_NULL = 0
DT_NEEDED = 1
DT_STRTAB = 5
EM_386 = 3
EM_PPC64 = 21
EM_X86_64 = 62
EM_AARCH64 = 183
PE_I386 = 0x14c
PE_AMD64 = 0x8664

# What check_linux accepts, by archive arch.
LINUX_EXPECT = {
    'x86_64': dict(cls=2, be=False, machine=EM_X86_64, interp_suffix='/ld-linux-x86-64.so.2'),
    'i686': dict(cls=1, be=False, machine=EM_386, interp_suffix='/ld-linux.so.2'),
    'aarch64': dict(cls=2, be=False, machine=EM_AARCH64, interp='/lib/ld-linux-aarch64.so.1'),
    'ppc64': dict(cls=2, be=True, machine=EM_PPC64, interp='/lib64/ld64.so.1'),
}


def die(msg):
    print(f'make-dist: {msg}', file=sys.stderr)
    raise SystemExit(1)


# Sizes the shell picks from a shortcut icon: the small list views, the
# Start menu, and the 256 image high-DPI tiles use.
ICO_SIZES = ((16, 16), (32, 32), (48, 48), (256, 256))


def rune_ico():
    """Windows icon for the Start menu, from share/rune.png.

    The archive carries the icon, so the machine that installs it does
    not convert the PNG.
    """
    png = ROOT / 'share' / 'rune.png'
    if not png.is_file():
        die(f'{png} is missing')
    try:
        from PIL import Image
    except ImportError:
        die('need Pillow (python3-pil) to convert share/rune.png')
    image = Image.open(png).convert('RGBA')
    buf = io.BytesIO()
    image.save(buf, format='ICO', sizes=list(ICO_SIZES))
    data = buf.getvalue()
    count = struct.unpack_from('<H', data, 4)[0] if len(data) >= 6 else 0
    if data[:4] != b'\x00\x00\x01\x00' or count != len(ICO_SIZES):
        die('share/rune.png did not convert to an icon')
    return data


def manifest_names(path):
    names = []
    for line in path.read_text(encoding='utf-8').splitlines():
        col = line.split('|', 1)[0].strip()
        if col == '' or col.startswith('#'):
            continue
        names.append(col)
    return names


def library_files(lib_root):
    """Paths relative to lib_root of every library install.sh would copy.

    A library is a directory with library.build. The compiler reads its
    MANIFEST; README.md is the overview beside the sources.
    """
    builds = sorted(p for p in lib_root.rglob('library.build') if p.is_file())
    if not builds:
        die(f'no library.build under {lib_root}')
    found = []
    for build in builds:
        manifest = build.parent / 'MANIFEST'
        if not manifest.is_file():
            die(f'{manifest} is missing (make manifests)')
        found.append(manifest.relative_to(lib_root))
        for name in manifest_names(manifest):
            src = build.parent / name
            if not src.is_file():
                die(f'{manifest} names {name}, which is not there')
            found.append(src.relative_to(lib_root))
        readme = build.parent / 'README.md'
        if readme.is_file():
            found.append(readme.relative_to(lib_root))
    return found


def _u16(n, be):
    return struct.pack('>H' if be else '<H', n)


def _u32(n, be):
    return struct.pack('>I' if be else '<I', n)


def _u64(n, be):
    return struct.pack('>Q' if be else '<Q', n)


def _i64(n, be):
    return struct.pack('>q' if be else '<q', n)


def _i32(n, be):
    return struct.pack('>i' if be else '<i', n)


class Elf:
    def __init__(self, data):
        if len(data) < 16 or data[:4] != ELFMAG:
            raise ValueError('not an ELF file')
        self.data = data
        self.cls = data[4]
        self.be = data[5] == 2
        if self.cls not in (1, 2) or data[5] not in (1, 2):
            raise ValueError('not an ELF file')
        self._phdrs = self._program_headers()

    def _unpack(self, fmt_le, offset):
        fmt = fmt_le.replace('<', '>') if self.be else fmt_le
        size = struct.calcsize(fmt)
        if offset + size > len(self.data):
            raise ValueError('truncated ELF')
        return struct.unpack_from(fmt, self.data, offset)

    def _program_headers(self):
        if self.cls == 2:
            e_phoff, = self._unpack('<Q', 32)
            e_phentsize, e_phnum = self._unpack('<HH', 54)
            entries = []
            for i in range(e_phnum):
                off = e_phoff + i * e_phentsize
                p_type, _flags = self._unpack('<II', off)
                p_offset, p_vaddr, _paddr, p_filesz, _memsz, _align = self._unpack('<QQQQQQ', off + 8)
                entries.append(dict(type=p_type, offset=p_offset, vaddr=p_vaddr, filesz=p_filesz))
            return entries
        e_phoff, = self._unpack('<I', 28)
        e_phentsize, e_phnum = self._unpack('<HH', 42)
        entries = []
        for i in range(e_phnum):
            off = e_phoff + i * e_phentsize
            p_type, p_offset, p_vaddr, _paddr, p_filesz = self._unpack('<IIIII', off)
            entries.append(dict(type=p_type, offset=p_offset, vaddr=p_vaddr, filesz=p_filesz))
        return entries

    def machine(self):
        return self._unpack('<H', 18)[0]

    def blob(self, offset, size):
        end = offset + size
        if offset < 0 or end > len(self.data):
            raise ValueError('segment runs past the end of the file')
        return self.data[offset:end]

    def interp(self):
        for p in self._phdrs:
            if p['type'] == PT_INTERP:
                return self.blob(p['offset'], p['filesz']).split(b'\0', 1)[0].decode('ascii')
        raise ValueError('no interpreter')

    def _vaddr_to_off(self, addr):
        for p in self._phdrs:
            if p['type'] == PT_LOAD and p['vaddr'] <= addr < p['vaddr'] + p['filesz']:
                return p['offset'] + (addr - p['vaddr'])
        raise ValueError('dynamic string address is not in a load segment')

    def needed(self):
        dyn = next((p for p in self._phdrs if p['type'] == PT_DYNAMIC), None)
        if dyn is None:
            return []
        step = 16 if self.cls == 2 else 8
        strtab = None
        needs = []
        off = dyn['offset']
        end = dyn['offset'] + dyn['filesz']
        while off + step <= end:
            if self.cls == 2:
                tag, val = self._unpack('<qQ', off)
            else:
                tag, val = self._unpack('<iI', off)
            off += step
            if tag == DT_NULL:
                break
            if tag == DT_STRTAB:
                strtab = val
            elif tag == DT_NEEDED:
                needs.append(val)
        if strtab is None:
            return []
        base = self._vaddr_to_off(strtab)
        names = []
        for val in needs:
            names.append(self.blob(base + val, len(self.data) - (base + val)).split(b'\0', 1)[0].decode('ascii'))
        return names


def check_linux(data, arch):
    if data.startswith(b'#!'):
        raise ValueError('is a script')
    try:
        elf = Elf(data)
    except ValueError as err:
        raise ValueError(str(err)) from err
    expect = LINUX_EXPECT[arch]
    if elf.cls != expect['cls'] or elf.be != expect['be'] or elf.machine() != expect['machine']:
        raise ValueError(f'is not a {arch} ELF file')
    interp = elf.interp()
    if 'interp' in expect:
        if interp != expect['interp']:
            raise ValueError(f'interpreter is {interp}, wanted {expect["interp"]}')
    elif not interp.endswith(expect['interp_suffix']):
        raise ValueError(f'interpreter is {interp}')
    for name in elf.needed():
        if name.startswith('libgmp'):
            raise ValueError(f'depends on {name}')


def check_windows(data, arch):
    if data.startswith(b'#!'):
        raise ValueError('is a script')
    if len(data) < 0x40 or data[:2] != b'MZ':
        raise ValueError('not a PE file')
    e_lfanew = struct.unpack_from('<I', data, 0x3c)[0]
    if e_lfanew + 6 > len(data) or data[e_lfanew:e_lfanew + 4] != b'PE\0\0':
        raise ValueError('not a PE file')
    machine = struct.unpack_from('<H', data, e_lfanew + 4)[0]
    want = PE_AMD64 if arch == 'x86_64' else PE_I386
    if machine != want:
        raise ValueError(f'PE machine is 0x{machine:x}, wanted 0x{want:x}')


def _elf_file(kind, interp, needed):
    """A small ELF with a real interpreter and dynamic section, for the checker."""
    expect = LINUX_EXPECT[kind]
    be = expect['be']
    cls = expect['cls']
    interp_b = interp.encode('ascii') + b'\0'
    blobs = [n.encode('ascii') + b'\0' for n in needed]
    dynstr = b'\0' + b''.join(blobs)
    need_off = []
    at = 1
    for blob in blobs:
        need_off.append(at)
        at += len(blob)
    phnum = 3
    ehsize = 64 if cls == 2 else 52
    phentsize = 56 if cls == 2 else 32
    phoff = ehsize
    content_off = phoff + phnum * phentsize
    interp_off = content_off
    dynstr_off = interp_off + len(interp_b)
    dyn_off = dynstr_off + len(dynstr)
    step = 16 if cls == 2 else 8
    dyn_size = step * (len(needed) + 2)  # NEEDED*, STRTAB, NULL
    total = dyn_off + dyn_size
    base = 0x400000
    # Build the dynamic section against the virtual address of dynstr.
    dyn = b''
    for off in need_off:
        if cls == 2:
            dyn += _i64(DT_NEEDED, be) + _u64(off, be)
        else:
            dyn += _i32(DT_NEEDED, be) + _u32(off, be)
    str_vaddr = base + dynstr_off
    if cls == 2:
        dyn += _i64(DT_STRTAB, be) + _u64(str_vaddr, be)
        dyn += _i64(DT_NULL, be) + _u64(0, be)
    else:
        dyn += _i32(DT_STRTAB, be) + _u32(str_vaddr, be)
        dyn += _i32(DT_NULL, be) + _u32(0, be)
    body = bytearray(total)
    body[interp_off:interp_off + len(interp_b)] = interp_b
    body[dynstr_off:dynstr_off + len(dynstr)] = dynstr
    body[dyn_off:dyn_off + len(dyn)] = dyn

    def phdr(p_type, offset, filesz, flags):
        if cls == 2:
            return (_u32(p_type, be) + _u32(flags, be) + _u64(offset, be) + _u64(base + offset, be)
                    + _u64(base + offset, be) + _u64(filesz, be) + _u64(filesz, be) + _u64(8, be))
        return (_u32(p_type, be) + _u32(offset, be) + _u32(base + offset, be) + _u32(base + offset, be)
                + _u32(filesz, be) + _u32(filesz, be) + _u32(flags, be) + _u32(4, be))

    ph = (phdr(PT_INTERP, interp_off, len(interp_b), 4)
          + phdr(PT_LOAD, 0, total, 5)
          + phdr(PT_DYNAMIC, dyn_off, len(dyn), 6))
    ident = bytearray(16)
    ident[0:4] = ELFMAG
    ident[4] = cls
    ident[5] = 2 if be else 1
    ident[6] = 1
    if cls == 2:
        header = (bytes(ident) + _u16(2, be) + _u16(expect['machine'], be) + _u32(1, be)
                  + _u64(0, be) + _u64(phoff, be) + _u64(0, be) + _u32(0, be)
                  + _u16(64, be) + _u16(phentsize, be) + _u16(phnum, be)
                  + _u16(0, be) + _u16(0, be) + _u16(0, be))
    else:
        header = (bytes(ident) + _u16(2, be) + _u16(expect['machine'], be) + _u32(1, be)
                  + _u32(0, be) + _u32(phoff, be) + _u32(0, be) + _u32(0, be)
                  + _u16(52, be) + _u16(phentsize, be) + _u16(phnum, be)
                  + _u16(0, be) + _u16(0, be) + _u16(0, be))
    body[0:len(header)] = header
    body[phoff:phoff + len(ph)] = ph
    return bytes(body)


def _pe_file(machine):
    pe_off = 0x80
    dos = bytearray(pe_off)
    dos[0:2] = b'MZ'
    struct.pack_into('<I', dos, 0x3c, pe_off)
    coff = struct.pack('<HHIIIHH', machine, 0, 0, 0, 0, 0, 0)
    return bytes(dos) + b'PE\0\0' + coff


def self_test():
    good = {
        'x86_64': _elf_file('x86_64', '/lib64/ld-linux-x86-64.so.2', ['libc.so.6', 'libm.so.6']),
        'i686': _elf_file('i686', '/lib/ld-linux.so.2', ['libc.so.6']),
        'aarch64': _elf_file('aarch64', '/lib/ld-linux-aarch64.so.1', ['libc.so.6']),
        'ppc64': _elf_file('ppc64', '/lib64/ld64.so.1', ['libc.so.6']),
    }
    for arch, data in good.items():
        check_linux(data, arch)
    check_windows(_pe_file(PE_AMD64), 'x86_64')
    check_windows(_pe_file(PE_I386), 'i686')
    bad = [
        ('x86_64', _elf_file('x86_64', '/lib64/ld-linux-x86-64.so.2', ['libgmp.so.10']), 'libgmp'),
        ('aarch64', _elf_file('aarch64', '/usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1', ['libc.so.6']), 'interpreter'),
        ('ppc64', _elf_file('ppc64', '/usr/powerpc64-linux-gnu/lib/ld64.so.1', ['libc.so.6']), 'interpreter'),
        ('x86_64', b'#!/bin/sh\n', 'script'),
        ('i686', good['x86_64'], 'not a i686'),
    ]
    for arch, data, text in bad:
        try:
            check_linux(data, arch)
        except ValueError as err:
            if text not in str(err):
                die(f'self-test: {arch} failed as {err}, which does not mention {text}')
        else:
            die(f'self-test: {arch} was accepted')
    try:
        check_windows(_pe_file(0xAA64), 'x86_64')
    except ValueError as err:
        if 'PE machine' not in str(err):
            die(f'self-test: arm64 PE failed as {err}')
    else:
        die('self-test: arm64 PE was accepted')
    try:
        check_windows(b'#!/bin/sh\n', 'i686')
    except ValueError:
        pass
    else:
        die('self-test: a script was accepted as a PE file')


def crlf(data):
    return data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')


def read_vm(path, system, arch, fixture):
    data = path.read_bytes()
    if fixture:
        return data
    try:
        if system == 'linux':
            check_linux(data, arch)
        else:
            check_windows(data, arch)
    except ValueError as err:
        die(f'{path}: {err}')
    return data


def build(args):
    if not VERSION_RE.fullmatch(args.version):
        die(f'version {args.version!r} is not made of letters, digits, and . _ + -')
    lib_root = Path(args.lib)
    libs = library_files(lib_root)
    linux = dict(args.linux)
    windows = dict(args.windows)
    if tuple(sorted(linux)) != tuple(sorted(LINUX_ARCH)):
        die(f'linux runtimes must be {", ".join(LINUX_ARCH)}')
    if tuple(sorted(windows)) != tuple(sorted(WINDOWS_ARCH)):
        die(f'windows runtimes must be {", ".join(WINDOWS_ARCH)}')

    def payload(system, vms):
        files = []
        for rel in libs:
            data = (lib_root / rel).read_bytes()
            files.append((f'lib/rune/{rel.as_posix()}', data, 0o644))
        files.append(('lib/rune/rune.rbc', Path(args.compiler).read_bytes(), 0o644))
        files.append(('lib/rune/rune-repl.img', Path(args.repl).read_bytes(), 0o644))
        files.append(('LICENSE', Path(args.license).read_bytes(), 0o644))
        files.append(('VERSION', (args.version + '\n').encode('ascii'), 0o644))
        for arch, path in sorted(vms.items()):
            name = 'runevm.exe' if system == 'windows' else 'runevm'
            data = read_vm(Path(path), system, arch, args.fixture)
            files.append((f'runtime/{arch}/{name}', data, 0o755))
        return files

    scripts = ROOT / 'scripts'
    linux_files = payload('linux', linux)
    linux_files.append(('install.sh', (scripts / 'dist-install.sh').read_bytes(), 0o755))
    windows_files = payload('windows', windows)
    for name, mode in (('install.bat', 0o644), ('uninstall.bat', 0o644)):
        windows_files.append((name, crlf((scripts / f'dist-{name}').read_bytes()), mode))
    windows_files.append(('register.ps1', (scripts / 'dist-register.ps1').read_bytes(), 0o644))
    windows_files.append(('share/rune.ico', rune_ico(), 0o644))
    for name in ('rune.cmd', 'rune-repl.cmd'):
        windows_files.append((f'wrappers/{name}', crlf((scripts / f'dist-{name}').read_bytes()), 0o644))

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    linux_name = f'rune-{args.version}-linux.tar.gz'
    windows_name = f'rune-{args.version}-windows.zip'
    write_tar(out / linux_name, f'rune-{args.version}-linux', linux_files)
    write_zip(out / windows_name, f'rune-{args.version}-windows', windows_files)
    print(out / linux_name)
    print(out / windows_name)


def write_tar(path, top, files):
    entries = sorted(((f'{top}/{name}', data, mode) for name, data, mode in files), key=lambda e: e[0])
    with path.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as gz:
            with tarfile.open(fileobj=gz, mode='w', format=tarfile.USTAR_FORMAT) as tar:
                for name, data, mode in entries:
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    info.mtime = 0
                    info.mode = mode
                    info.uid = 0
                    info.gid = 0
                    info.uname = ''
                    info.gname = ''
                    info.type = tarfile.REGTYPE
                    tar.addfile(info, io.BytesIO(data))


def write_zip(path, top, files):
    entries = sorted(((f'{top}/{name}', data, mode) for name, data, mode in files), key=lambda e: e[0])
    with zipfile.ZipFile(path, 'w') as archive:
        for name, data, mode in entries:
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = (mode & 0xFFFF) << 16
            archive.writestr(info, data)


def parse_map(values):
    found = {}
    for item in values:
        if '=' not in item:
            die(f'expected ARCH=PATH, got {item}')
        arch, path = item.split('=', 1)
        found[arch] = path
    return found


def main(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--self-test', action='store_true')
    p.add_argument('--write-ico', help='write the Windows icon made from share/rune.png and stop')
    p.add_argument('--version')
    p.add_argument('--out')
    p.add_argument('--lib')
    p.add_argument('--license', default=str(ROOT / 'LICENSE'))
    p.add_argument('--compiler')
    p.add_argument('--repl')
    p.add_argument('--linux', action='append', default=[])
    p.add_argument('--windows', action='append', default=[])
    p.add_argument('--fixture', action='store_true',
                   help='pack the runtimes as given, without reading their headers')
    args = p.parse_args(argv)
    if args.self_test:
        self_test()
        return
    if args.write_ico:
        path = Path(args.write_ico)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(rune_ico())
        return
    if not args.version or not args.out or not args.lib or not args.compiler or not args.repl:
        die('need --version, --out, --lib, --compiler and --repl')
    args.linux = parse_map(args.linux)
    args.windows = parse_map(args.windows)
    build(args)


if __name__ == '__main__':
    main(sys.argv[1:])
