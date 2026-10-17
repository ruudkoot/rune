from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
# Recover the complete counterexample from the independent paragraph checker.
scope={};exec((p/'independent.py').read_text().replace('p=Path(__file__).resolve().parent','p=Path('+repr(str(p))+')'),scope)
record=scope['record'];gap=record['source_suboptimal_paragraphs'][0];words=scope['original'][gap['paragraph']]
(p/'anomaly.input').write_text(' '.join(words)+'\n')
text=(p/'observer-source/Observer.hs').read_text();assert'K.fmt text'in text
(p/'observer-source/Quadratic.hs').write_text(text.replace('K.fmt text','K.fmt1 text'))
with(p/'quadratic-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','quadratic','Quadratic.hs'],cwd=p/'observer-source',stdout=f,stderr=subprocess.STDOUT,check=True)
for variant in ['observer','quadratic']:
 r=subprocess.run([str(p/'observer-source'/variant),str(p/'anomaly.input')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True)
 (p/('anomaly-'+variant+'.reference')).write_bytes(r.stdout)
 rows=r.stdout.decode().splitlines();value=sum((63-len(row))**2 for row in rows[:-1])
 print(variant,len(words),len(rows),'cost',value)
 assert value==(5 if variant=='observer'else 1)
