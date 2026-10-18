from pathlib import Path
import json
p=Path(__file__).resolve().parent
names=[r.split('\t')[0]for r in(p/'observe.stdout').read_text().splitlines()]
t='(* Exact original embedded text; expectations are reviewed report lengths. *)\nstructure BenchTransformInputs=struct\n val all=[\n'
t+=',\n'.join('('+json.dumps(name)+','+json.dumps((p/(name+'.input')).read_text())+','+str(len((p/(name+'-report.reference')).read_bytes()))+')'for name in names)
t+='\n ]\n val order=["fft","fib","fibsum","flipflop","gamma","hamming","setreset","wave4"]\n fun lookup name=case List.find(fn(key,_,_)=>key=name)all of SOME value=>value|NONE=>raise Fail"unknown transform input"\n val selected=List.map lookup order\nend\n'
assert t.isascii()
(p/'inputs.sml').write_text(t)
