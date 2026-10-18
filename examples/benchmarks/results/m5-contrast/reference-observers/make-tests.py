from pathlib import Path
import json
p=Path(__file__).resolve().parent
def real(value):
 text=format(value,'.17g').replace('-','~')
 return text if'.'in text or'e'in text.lower()else text+'.0'
lines=['structure SauvolaSupportTests=struct',' structure I=BenchSauvolaImage',' structure K=BenchSauvola',' structure H=BenchSauvolaHash']
rows=json.loads((p/'float-hashes.json').read_text())
for i,row in enumerate(rows):
 a,b=row['key'];lines.append(' val _=T.check("contrast/source-float-hash/'+str(i)+'",fn()=>H.pairReal('+real(a)+','+real(b)+')='+str(row['hash'])+')')
lines+=[''' val _=T.check("contrast/source-memo-sharing-and-clear-bound",fn()=>
 let val calls=ref 0
     val f=BenchSauvolaIntMemo.memo(fn(k,_) =>(calls:= !calls+1;k+1))
     val _=I.loop 0 1000(fn i=>ignore(f(i,0)))
     val _=f(0,0)val a= !calls
     val _=f(1001,0)val b= !calls
     val _=f(0,0)val c= !calls
     val _=f(1001,0)val d= !calls
 in [a,b,c,d]=[1001,1002,1003,1003]end)''',
''' val _=T.check("contrast/brightness-source-weights",fn()=>I.brightness{r=255,g=0,b=0}=54 andalso I.brightness{r=0,g=255,b=0}=182 andalso I.brightness{r=0,g=0,b=255}=19)''',
''' val _=T.check("contrast/subimage-copy-isolation",fn()=>let val a=I.create 4 4 val b=I.sub a 1 1 2 2 val _=I.set b 0 0{r=1,g=2,b=3}in I.get a 1 1={r=0,g=0,b=0}andalso I.get b 0 0={r=1,g=2,b=3}end)''',
''' val _=T.check("contrast/out-of-range-color-rejected",fn()=>((I.set(I.create 1 1)0 0{r=256,g=0,b=0};false)handle Domain=>true))''',
''' val _=T.check("contrast/source-window-edges",fn()=>K.window 32 32 0 0={x0=0,y0=0,x1=15,y1=15}andalso K.window 32 32 31 31={x0=16,y0=16,x1=31,y1=31})''',
''' val _=T.check("contrast/binary64-zero-normalization",fn()=>H.words 0.0=H.words(~0.0))''',
'end']
(p/'support-tests.sml').write_text('\n'.join(lines)+'\n')
