"""Reproduce the compilation-only audit in an explicit scratch directory."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys

here=Path(__file__).resolve().parent
root=here.parents[3]
metadata=json.loads((here/'metadata.json').read_text())
if len(sys.argv)!=2:raise SystemExit('usage: compile.py SCRATCH_DIRECTORY')
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
compiler=os.environ.get('OCAMLFIND','ocamlfind')
version=subprocess.check_output([compiler,'ocamlopt','-version'],text=True).strip()
if version!=metadata['compiler_version']:raise SystemExit('expected OCaml '+metadata['compiler_version']+', found '+version)
for item in metadata['programs']:
    source=root/'tests/benchmarks/data/sandmark-opaque'/(item['name']+'.ml')
    assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'],source
    shutil.copy(source,out/source.name)
    def limits():resource.setrlimit(resource.RLIMIT_AS,(item['memory_bytes'],item['memory_bytes']))
    with(out/(item['name']+'.cmm')).open('w')as log:
        subprocess.run([compiler,'ocamlopt',*metadata['compiler_options'],source.name],cwd=out,
                       stdout=log,stderr=subprocess.STDOUT,check=True,
                       timeout=item['timeout'],preexec_fn=limits)
    print('PASS compile-only opaque probe',item['name'])
