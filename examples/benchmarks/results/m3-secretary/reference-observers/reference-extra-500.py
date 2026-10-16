from pathlib import Path
import json
ref=Path(__file__).resolve().parent
scope={'__file__':str(ref/'reference.py')};exec((ref/'reference.py').read_text().split('allcounts=')[0],scope)
counts=[0]*5
for seed in range(1,501):
 values,_=scope['permutation'](seed)
 for index,k in enumerate(range(35,40)):
  best=max(values[:k]);candidate=next((v for v in values[k:]if v>=best),None);counts[index]+=candidate==100
raw=scope['subprocess'].check_output([str(ref/'observer'),'500'],timeout=615,preexec_fn=scope['limit']).decode();assert json.loads(raw)==counts
(ref/'500.expected').write_text(raw);(ref/'500.results').write_text(''.join(str(k)+' '+str(count)+' '+format(count/500,'.17g')+'\n'for k,count in zip(range(35,40),counts)))
(ref/'normal-500-metadata.json').write_text(json.dumps(dict(trials=500,ks=list(range(35,40)),counts=counts,reason='bounded comparative normal; original5000isexplicitlarge;larger50000retainedreference',comparison='complete original count expression and independent full-permutation model'),indent=2)+'\n')
print('PASS original and independent selected normal500',counts)
