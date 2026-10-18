from pathlib import Path
p=Path(__file__).resolve().parent
def real(text):
 text=text.replace('-','~')
 return text if '.'in text or'e'in text.lower()else text+'.0'
blocks=(p/'de.reference').read_text().split('limit ')[1:]
lines=['structure G2OptimizerTests=struct',' structure O=BenchG2Optimization',' fun close(a,b)=BenchG2Check.close(a,b,1.0E~12,1.0E~12)']
for block in blocks:
 rows=block.splitlines();limit=int(rows[0]);f,calls,status,x0,x1=rows[1].split()[1:]
 trace=[row.split()[1:]for row in rows[2:]]
 recorded='['+','.join('('+n+','+real(v)+')'for n,v in trace)+']'
 name={'iterations':'MaxIterations','evaluations':'MaxEvaluations','target':'TargetReached'}[status]
 lines.append(''' val _=T.check("G2/source-DE-sphere/'''+str(limit)+'''",fn()=>
 let val trace=ref[]
     val result=O.optimize(O.parameters 2)
       (fn x=>Array.foldl(fn(v,h)=>h+v*v)0.0 x)
       (Array.fromList[~2.0,~2.0])(Array.fromList[2.0,2.0])
       (fn n=>fn value=>trace:=(n,value):: !trace)
       {maxit=10000,maxf='''+str(limit)+''',target=0.0}
 in #evaluations result='''+calls+''' andalso #status result=O.'''+name+'''
    andalso close(#f result,'''+real(f)+''')
    andalso close(Array.sub(#x0 result,0),'''+real(x0)+''')
    andalso close(Array.sub(#x0 result,1),'''+real(x1)+''')
    andalso ListPair.allEq(fn((n,a),(m,b))=>n=m andalso close(a,b))(rev(!trace),'''+recorded+''')end)''')
lines.append('end');(p/'de-tests.sml').write_text('\n'.join(lines)+'\n')
