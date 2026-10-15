#!/usr/bin/env python3
"""Build and test the pinned GMP dependency in a repository-local prefix."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
VERSION = '6.3.0'
SHA256 = 'a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898'
URL = f'https://gmplib.org/download/gmp/gmp-{VERSION}.tar.xz'
# Both release sites are listed at https://gmplib.org/#DOWNLOAD. Prefer GNU
# so CI does not depend on access to the GMP project's own server.
DOWNLOAD_URLS = (f'https://ftp.gnu.org/gnu/gmp/gmp-{VERSION}.tar.xz', URL)


class CommandFailed(RuntimeError):
    pass


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download_archive(archive, run):
    """Return the download URL, or None for a checksum-verified cached file."""
    if archive.exists():
        if digest(archive) != SHA256:
            raise RuntimeError('GMP cached source checksum mismatch')
        return None
    archive.parent.mkdir(parents=True, exist_ok=True)
    failures = []
    # A private partial file also permits independent cross builds to fetch
    # the same archive without overwriting each other's incomplete transfers.
    with tempfile.TemporaryDirectory(prefix=archive.name+'.', dir=archive.parent) as temporary:
        part = Path(temporary)/archive.name
        for index, url in enumerate(DOWNLOAD_URLS, 1):
            part.unlink(missing_ok=True)
            try:
                run(['curl', '--fail', '--location', '--silent', '--show-error',
                     '--connect-timeout', '15', '--max-time', '60',
                     '--retry', '2', '--retry-delay', '2', '--retry-max-time', '180',
                     '--retry-connrefused', url, '-o', part], f'download-{index}')
            except (CommandFailed, subprocess.TimeoutExpired) as error:
                failures.append(f'{url}: {error}')
                print(f'GMP download failed: {failures[-1]}', file=sys.stderr, flush=True)
                continue
            # A successful HTTP response is not enough. A mismatch is fatal,
            # including on mirrors, and never publishes anything to the cache.
            if digest(part) != SHA256:
                raise RuntimeError(f'GMP source checksum mismatch from {url}')
            part.replace(archive)
            print(f'GMP source verified: {url}', flush=True)
            return url
    raise RuntimeError('GMP download failed from all release sites:\n'+'\n'.join(failures))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', default='build/deps/gmp/native')
    parser.add_argument('--cc', default=os.environ.get('CC','cc'))
    parser.add_argument('--cflags', default='-O2')
    parser.add_argument('--ldflags', default='')
    parser.add_argument('--host', default='')
    parser.add_argument('--build', default='')
    parser.add_argument('--cc-for-build', default='cc')
    parser.add_argument('--runner', default='')
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--timeout', type=int, default=1800)
    parser.add_argument('--disable-assembly', action='store_true')
    parser.add_argument('--enable-fat', action='store_true', help='runtime CPU selection for x86 packages')
    parser.add_argument('--with-pic', action='store_true', help='position-independent static objects')
    parser.add_argument('--abi', choices=('', '32', '64'), default='')
    args = parser.parse_args()
    if args.jobs < 1 or args.timeout < 1:
        parser.error('jobs and timeout must be positive')
    if args.enable_fat and args.disable_assembly:
        parser.error('fat CPU selection requires assembly')
    os.chdir(ROOT)
    prefix = Path(args.prefix).resolve()
    config = {**vars(args), 'prefix':str(prefix), 'version':VERSION, 'sha256':SHA256,
              'url':URL, 'download_urls':list(DOWNLOAD_URLS),
              'linkage':'static', 'upstream_tests':'required',
              'recipe_sha256':digest(Path(__file__))}
    key = hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest()[:16]
    build = ROOT/'build/deps/gmp-build'/key
    build.mkdir(parents=True, exist_ok=True)
    metadata = prefix/'rune-gmp.json'
    if metadata.exists():
        previous = json.loads(metadata.read_text())
        if previous.get('config') == config and (prefix/'lib/libgmp.a').exists() and (prefix/'include/gmp.h').exists():
            if previous.get('library_sha256') == digest(prefix/'lib/libgmp.a') and previous.get('header_sha256') == digest(prefix/'include/gmp.h'):
                print(f'GMP {VERSION}: verified existing build {prefix}')
                return

    commands = []
    def run(argv, name, cwd=build, env=None):
        argv = list(map(str,argv))
        commands.append({'name':name,'argv':argv,'cwd':str(cwd)})
        (build/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
        started = time.time()
        print(f'GMP {name}: {shlex.join(argv)}',flush=True)
        with (build/(name+'.log')).open('wb') as log:
            p = subprocess.Popen(argv,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            try:
                code = p.wait(timeout=args.timeout)
            except BaseException:
                os.killpg(p.pid,signal.SIGKILL)
                p.wait()
                (build/(name+'.status')).write_text('interrupted or timed out\n')
                raise
        (build/(name+'.status')).write_text(f'exit:{code}\nseconds:{time.time()-started:.3f}\n')
        if code:
            # Keep a bounded diagnostic in the CI console as well as the full
            # artifact, which is especially useful before any tests can start.
            with (build/(name+'.log')).open('rb') as log:
                log.seek(max(0, log.seek(0, os.SEEK_END)-4096))
                print(log.read().decode(errors='replace'), file=sys.stderr, flush=True)
            raise CommandFailed(f'GMP {name} failed ({code}); see {build/(name+".log")}')

    downloads = ROOT/'build/deps/downloads'
    downloads.mkdir(parents=True,exist_ok=True)
    archive = downloads/f'gmp-{VERSION}.tar.xz'
    download_url = download_archive(archive, run)
    source_root = build/'source'
    source = source_root/f'gmp-{VERSION}'
    if not (source/'configure').exists():
        source_root.mkdir(parents=True,exist_ok=True)
        with tarfile.open(archive) as package:
            package.extractall(source_root,filter='data')

    with tarfile.open(archive) as package:
        for member in package.getmembers():
            installed = source_root/member.name
            if member.isfile():
                stream = package.extractfile(member)
                if stream is None or not installed.is_file() or hashlib.sha256(stream.read()).hexdigest() != digest(installed):
                    raise RuntimeError(f'GMP source cache differs from the pinned archive: {member.name}')
            elif member.issym() and (not installed.is_symlink() or os.readlink(installed) != member.linkname):
                raise RuntimeError(f'GMP source symlink differs from the pinned archive: {member.name}')

    environment = {**os.environ,'CC':args.cc,'CFLAGS':args.cflags,'LDFLAGS':args.ldflags,
                   'CC_FOR_BUILD':args.cc_for_build}
    environment.pop('ABI', None)
    environment['CPPFLAGS'] = ''
    if args.abi:
        environment['ABI'] = args.abi
    configure = [source/'configure', '--prefix='+str(prefix),'--disable-shared','--enable-static']
    # Fat assembly dispatch does not neutralize CPU-specific inline helpers
    # in C. A native package must also name a generic compiler target, rather
    # than let GMP's config.guess select e.g. haswell and enable LZCNT/MULX.
    host_target = args.host
    if args.enable_fat and not host_target:
        host_target = subprocess.check_output([*shlex.split(args.cc),'-dumpmachine'],text=True).strip()
    if host_target:
        configure += ['--host='+host_target]
    # WSL can execute Windows targets, and binfmt can execute emulated targets.
    # That does not make them suitable build-machine generators. Giving both
    # triples keeps configure's cross-compilation decision independent of that.
    if host_target or args.build:
        build_target = args.build or subprocess.check_output([*shlex.split(args.cc_for_build),'-dumpmachine'],text=True).strip()
        configure += ['--build='+build_target]
    if args.disable_assembly:
        configure += ['--disable-assembly']
    if args.enable_fat:
        configure += ['--enable-fat']
    if args.with_pic:
        configure += ['--with-pic']
    run(configure,'configure',env=environment)
    run(['make',f'-j{args.jobs}'],'build',env=environment)
    check = ['make',f'-j{args.jobs}','check']
    if args.runner:
        check += ['LOG_COMPILER='+args.runner]
    run(check,'check',env=environment)
    run(['make','install'],'install',env=environment)
    configured = dict(re.findall(r'^(ABI|CC|CFLAGS|CPPFLAGS|GMP_LDFLAGS|build|host) = (.*)$',
                                (build/'Makefile').read_text(),re.MULTILINE))
    record = {'config':config,'configured':configured,'commands':commands,'build_directory':str(build),
              'source_archive':{'path':str(archive), 'sha256':SHA256, 'download_url':download_url},
              'c_compiler':subprocess.check_output([*shlex.split(args.cc),'--version'],text=True).splitlines()[0],
              'library_sha256':digest(prefix/'lib/libgmp.a'),
              'header_sha256':digest(prefix/'include/gmp.h'), 'upstream_check':'pass'}
    metadata.write_text(json.dumps(record,indent=2)+'\n')
    license_dir = prefix/'share/licenses/gmp'
    license_dir.mkdir(parents=True,exist_ok=True)
    for name in ('COPYING','COPYING.LESSERv3','COPYINGv2','COPYINGv3'):
        if (source/name).exists():
            (license_dir/name).write_bytes((source/name).read_bytes())
    print(f'GMP {VERSION}: built and tested in {prefix}')


if __name__ == '__main__':
    main()
