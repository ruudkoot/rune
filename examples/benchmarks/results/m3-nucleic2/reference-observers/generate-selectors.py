from pathlib import Path
p=Path(__file__).resolve().parent
trans=['dgf_base_tfo','p_o3XXX_275_tfo','p_o3XXX_180_tfo','p_o3XXX_60_tfo']
points=['p','o1p','o2p','o5XXX','c5XXX','h5XXX','h5XXXXXX','c4XXX','h4XXX','o4XXX','c1XXX','h1XXX','c2XXX','h2XXXXXX','o2XXX','h2XXX','c3XXX','h3XXX','o3XXX','n1','n3','c2','c4','c5','c6']
fields=trans+points+['specific']
out=''
for name in ['C1XXX','C2','C3XXX','C4','C4XXX','N1','O3XXX','P','dgf_base_tfo','p_o3XXX_180_tfo','p_o3XXX_275_tfo','p_o3XXX_60_tfo']:
 target=name[0].lower()+name[1:]if name[0].isupper()else name
 assert target in fields
 pattern=['value'if f==target else'_'for f in fields]
 out+=' fun nuc_'+name+' n=D.delay(fn()=>let val Nuc('+','.join(pattern)+')=D.force n in D.force value end)\n'
for ctor in ['A','C','G']:
 pattern=['specific'if f=='specific'else'_'for f in fields]
 out+=' fun is_'+ctor+' n=let val Nuc('+','.join(pattern)+')=D.force n in case D.force specific of '+ctor+' _=>true|_=>false end\n'
for ctor,count,index in [('A',8,2),('G',9,2)]:
 pattern=['specific'if f=='specific'else'_'for f in fields]
 arms=['value'if i==index else'_'for i in range(count)]
 out+=' fun r'+ctor+'_N9 n=D.delay(fn()=>let val Nuc('+','.join(pattern)+')=D.force n\n   in case D.force specific of '+ctor+'('+','.join(arms)+')=>D.force value|_=>raise Match end)\n'
out+=' fun make_relative_nuc t n=D.delay(fn()=>\n   let val Nuc('+','.join(fields)+')=D.force n\n'
out+='       val relativeSpecific=case D.force specific of\n'
for i,(ctor,count)in enumerate([('A',8),('C',6),('G',9),('U',5)]):
 args=['a'+str(j)for j in range(count)]
 out+=('          'if i==0 else'         |')+ctor+'('+','.join(args)+')=>D.delay(fn()=>'+ctor+'('+','.join('tfo_apply t '+v for v in args)+'))\n'
out+='   in Nuc('+','.join(trans+['tfo_apply t '+v for v in points]+['relativeSpecific'])+')end)\n'
(p/'selectors.sml').write_text(out)
print('selectors and shared-coordinate construction generated')
