from pathlib import Path
import json
p=Path(__file__).resolve().parent
lines=['structure StdlibHashtblProgramTests=struct',' structure P=BenchStdlibHashtblPrograms']
for row in json.loads((p/'program-cases.json').read_text()):
 lines.append(' val _=T.check("stdlib-hashtbl-program/'+row['benchmark']+'/'+str(row['iterations'])+'",fn()=>P.run '+json.dumps(row['benchmark'])+' '+str(row['iterations'])+'='+json.dumps(row['expected'])+')')
lines += [
' val _=T.check("stdlib-hashtbl-program/reject-corrupt-bindings",fn()=>let val table=P.H.create P.H.Generic 1 val _=P.H.add table 1 2 in ((P.checkRange table 1 1 1;false)handle Fail _=>true)end)',
' val _=T.check("stdlib-hashtbl-program/signed63-boundary",fn()=>P.double(IntInf.pow(2,61))=IntInf.~(IntInf.pow(2,62)))',
' val _=T.check("stdlib-hashtbl-program/signed63-wrap-zero",fn()=>P.double(IntInf.~(IntInf.pow(2,62)))=IntInf.fromInt 0)',
'end']
(p/'program-tests.sml').write_text('\n'.join(lines)+'\n')
