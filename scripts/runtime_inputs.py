"""Resolve transitive runtime headers with the compiler used for the VM."""
from pathlib import Path
import shlex
import subprocess


def runtime_inputs(cc, flags, cppflags, config_header, sources, headers):
    command=[*cc,*flags,'-Iruntime',*cppflags,'-include',str(config_header),'-MM',*sources]
    dependencies=subprocess.check_output(command,text=True).replace('\\\n',' ')
    root=Path.cwd().resolve();runtime=root/'runtime'
    files=set(sources+headers)
    for word in shlex.split(dependencies):
        if word.endswith(':'):
            continue
        path=Path(word).resolve()
        if path.is_relative_to(runtime):
            files.add(str(path.relative_to(root)))
    return sorted(files)
