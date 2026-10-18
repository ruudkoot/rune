from pathlib import Path
import shutil,subprocess
p=Path(__file__).resolve().parent;d=p/'demand-source';d.mkdir(exist_ok=True)
shutil.copy(p/'source/vector3f.ml',d/'vector3f.ml')
s=(p/'source/triangle.ml').read_text();i=s.rfind('\nend');assert i>0
s=s[:i]+'\n method benchmarkDemand = [Lazy.is_val normal;Lazy.is_val tangent;Lazy.is_val area]\n'+s[i:]
(d/'triangle.ml').write_text(s)
source='''let ()=
 let data=Scanf.Scanning.from_string"(0 0 0)(1 0 0)(0 1 0)(1 1 1)(0 0 0)"in
 let triangle=new Triangle.obj data in
 let show()=print_endline(String.concat " "(List.map string_of_bool triangle#benchmarkDemand))in
 show();ignore triangle#area;show();ignore triangle#normal;show();ignore triangle#tangent;show()
'''
(d/'Observer.ml').write_text(source)
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','demand-observer','vector3f.ml','triangle.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'demand-observer')],cwd=d,timeout=60);(p/'demand.reference').write_bytes(out)
assert out.decode().splitlines()==['false false false','false false true','true false true','true true true']
print('PASS original lazy geometry field demand states')
