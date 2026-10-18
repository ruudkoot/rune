from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'report-observer-source'
(d/'HashReport.hs').write_text('module Main where\nimport NofibUtils(hash)\nimport Data.Word(Word64)\nimport Numeric(showHex)\nmain=getContents >>= (\\text->putStrLn(showHex(fromIntegral(hash text)::Word64)""))\n')
with(p/'hash-build.log').open('w')as log:subprocess.run(['ghc','-O2','-o','hash-report','HashReport.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
records=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for file in ['data.0','data.1','data.2','fem.stdin']:
 rows={line.split()[0]:line.split()[1:]for line in(p/(file+'.observations')).read_text().splitlines()}
 ints=list(map(int,rows['idatabase']));u=rows['displacement'];f=rows['forces']
 report=(p/(file+'.report')).read_bytes();value=0
 for byte in report:value=(value*31+byte)%(1<<64)
 expected=format(value,'x')
 r=subprocess.run([str(d/'hash-report')],input=report,capture_output=True,check=True,timeout=30,preexec_fn=cap)
 assert r.stdout.decode().strip()==expected
 text='FEM32 '+str(ints[0])+' '+str(ints[1])+'\nu '+str(len(u))+' '+' '.join(u)+'\nf '+str(len(f))+' '+' '.join(f)+'\nhash '+expected+'\n'
 (p/(file+'.reference')).write_text(text)
 records.append(dict(input=file,report_bytes=len(report),result_floats=len(u)+len(f),hash=expected))
print(records)
(p/'final-reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
