from pathlib import Path
import json
p=Path(__file__).resolve().parent
def sml(n):return str(n).replace('-','~')
def real(n):
 text=sml(n)
 return text if '.'in text or 'e'in text.lower()else text+'.0'
lines=['structure G2SupportTests=struct',' structure D=BenchG2Date',' structure M=BenchG2Math',' structure R=BenchG2Random',' fun close(a,b)=BenchG2Check.close(a,b,1.0E~12,1.0E~12)']
for i,line in enumerate((p/'support.reference').read_text().splitlines()):
 fields=line.split()
 if fields[0]=='date':
  date,value=fields[1:];expr='D.ofString '+json.dumps(date)+'='+sml(value)
 elif fields[0]=='month':
  date,amount,value,year,month,day=fields[1:]
  expr='let val value=D.addMonths(D.ofString '+json.dumps(date)+')('+sml(amount)+') val g=D.toGregorian value in value='+sml(value)+' andalso #year g='+year+' andalso #month g='+month+' andalso #day g='+day+'end'
 elif fields[0]=='cdf':expr='BenchG2Check.close(M.gaussianP('+real(fields[1])+'),'+real(fields[2])+',1.0E~10,1.0E~10)'
 else:continue
 lines.append(' val _=T.check("G2/source-support/'+str(i)+'",fn()=>'+expr+')')
randoms=(p/'random.reference').read_text().splitlines()
ints=[int(x.split()[1])for x in randoms if x.startswith('int ')]
reals=[x.split()[1]for x in randoms if x.startswith('float ')]
lines+=[' val _=T.check("G2/source-seed0-integers",fn()=>let val state=R.create()in List.tabulate(20,fn _=>R.integer state 40)=['+','.join(map(str,ints))+']end)',
' val _=T.check("G2/source-seed0-floats",fn()=>let val state=R.create()val actual=List.tabulate(20,fn _=>R.real state 1.0)in ListPair.allEq close(actual,['+','.join(real(x)for x in reals)+'])end)']
rootrow=next(x for x in(p/'support.reference').read_text().splitlines()if x.startswith('root '))
trace=next(x for x in(p/'support.reference').read_text().splitlines()if x.startswith('order ')).split()[1].split(',')
lines.append(''' val _=T.check("G2/source-Brent-root-and-evaluation-order",fn()=>
 let val calls=ref[]val value=M.brent 0.0 2.0(fn x=>(calls:=x:: !calls;x*x-2.0))1.0E~10
 in close(value,'''+real(rootrow.split()[1])+''')andalso ListPair.allEq close(rev(!calls),['''+','.join(real(x)for x in trace)+'''])end)''')
lines+=[' val _=T.check("G2/negative-root-tolerance-rejected",fn()=>((M.brent 0.0 2.0(fn x=>x*x-2.0)(~1.0);false)handle Fail _=>true))',
' val _=T.check("G2/invalid-leap-century-rejected",fn()=>((D.ofString"2100-02-29";false)handle Fail _=>true))',
'end']
(p/'support-tests.sml').write_text(('\n'.join(lines)+'\n').replace('=~','= ~'))
