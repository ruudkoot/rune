from pathlib import Path
import json
p=Path(__file__).resolve().parent
def sml(expr):
 kind=expr[0]
 if kind=='num':return'cn ('+str(expr[1]).replace('-','~')+':IntInf.int)'
 if kind=='bool':return'cb '+str(expr[1]).lower()
 if kind=='fun':return'cf '+json.dumps(expr[1])
 if kind=='var':return'variable '+json.dumps(expr[1])
 if kind=='app':return'app ('+sml(expr[1])+') ('+sml(expr[2])+')'
 if kind=='lam':return'lam ['+','.join('named '+json.dumps(n)for n in expr[1])+'] ('+sml(expr[2])+')'
 if kind=='let':return'lett '+str(expr[1]).lower()+' ['+','.join('(named '+json.dumps(n)+','+sml(rhs)+')'for n,rhs in expr[2])+'] ('+sml(expr[3])+')'
 raise AssertionError(kind)
records=json.loads((p/'ast-observations.json').read_text())
for i,(name,input,plain,full)in enumerate(records):
 for label,value in [('input',input),('plain',plain),('full',full)]:(p/('case-'+str(i)+'-'+label+'.json')).write_text(json.dumps(value,separators=(',',':'))+'\n')
(p/'cases.sml').write_text("fun cases()=["+','.join('('+json.dumps(name)+','+sml(input)+')'for name,input,_,_ in records)+"]\n")
