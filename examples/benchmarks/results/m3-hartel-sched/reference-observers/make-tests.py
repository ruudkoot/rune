from pathlib import Path
import json
p=Path(__file__).resolve().parent
records=json.loads((p/'observations.json').read_text())
lines=['structure SchedTests=struct',' structure D=BenchNeed',' structure L=BenchLazy',' structure N=BenchSchedFn(BenchNeed)',' structure E=BenchSchedFn(BenchStrict)',' fun check name f=T.check("sched/"^name,f)']
for variant in ['N','E']:
 for n,t,count,low,high,total,hash in records:
  if n==14:continue
  expected='('+str(count)+','+str(low)+','+str(high)+',valOf(IntInf.fromString"'+str(total)+'"),0wx'+format(hash,'X')+')'
  lines.append(' val _=check"source-tree/'+variant+'/'+str(n)+'/'+str(t)+'"(fn()=>'+variant+'.statistics('+variant+'.schedule('+variant+'.input '+str(n)+')'+str(t)+')='+expected+')')
lines+=[''' val _=check"lazy-anyjob-empty-keeps-pid-pending"(fn()=>
 let val pid=D.delay(fn()=>raise Fail"unused pid")
     val selected=N.second(N.anyJob(N.F.cons(N.emptyStat(),N.F.empty()))(N.F.empty())pid)
 in not(N.null selected)andalso N.isEmptyStat(N.head selected)end)''',
''' val _=check"lazy-anyjob-fork-skips-unused-fields"(fn()=>
 let val bad=D.delay(fn()=>raise Fail"unused scalar")
     val definition=D.delay(fn()=>raise Fail"unused definition")
     val state=N.stat(N.value 1)bad bad bad definition
     val selected=N.second(N.anyJob(N.F.cons(state,N.F.empty()))(N.F.empty())bad)
 in N.mark(N.head selected)=1 end)''',
''' val _=check"lazy-perform-terminal-projection-skips-pid"(fn()=>
 let val pid=D.delay(fn()=>raise Fail"unused pid")
     val p=N.procCell pid(N.emptyStat())
 in N.null(N.first(N.perform(N.F.cons(p,N.F.empty()))1))end)''',
''' val _=check"lazy-empty-ack-skips-parent"(fn()=>
 N.null(N.acknowledge(D.delay(fn()=>raise Fail"unused parent"))(N.F.empty())))''',
''' val _=check"lazy-empty-child-skips-parent"(fn()=>
 N.isEmptyStat(N.addChild(N.emptyDef())(D.delay(fn()=>raise Fail"unused parent"))))''',
''' val _=check"lazy-leaf-child-does-not-force-join-or-id"(fn()=>
 let val bad=D.delay(fn()=>raise Fail"unused scalar")
     val child=D.delay(fn()=>raise Fail"unused child")
     val definition=D.delay(fn()=>N.JobDef(bad,N.value 0,bad,child,child))
 in N.mark(N.addChild definition bad)=4 end)''',
''' val _=check"source-pair-fields-are-shared"(fn()=>
 let val calls=ref 0
     val pair=N.pair(fn()=>(calls:= !calls+1;N.F.empty()))(fn()=>(calls:= !calls+1;N.F.empty()))
     val _=N.first pair val _=N.first pair val _=N.second pair val _=N.second pair
 in !calls=2 end)''',
''' val _=check"sandwich-hints-remain-unforced"(fn()=>
 let val hint=L.delay(fn()=>raise Fail"unused metadata")
 in N.sandwich(fn(a,b)=>a+b)(N.Sandwarg(2,hint))(N.Sandwarg(3,hint))=5 end)''',
''' val _=check"strict-variant-also-keeps-control-hints-unforced"(fn()=>
 let val hint=L.delay(fn()=>raise Fail"unused metadata")
 in E.sandwich(fn(a,b)=>a+b)(E.Sandwarg(2,hint))(E.Sandwarg(3,hint))=5 end)''',
''' val _=check"strict-finite-fields-evaluate"(fn()=>
 let val calls=ref 0 val field=BenchStrict.delay(fn()=>(calls:= !calls+1;7))
 in !calls=1 andalso BenchStrict.force field=7 end)''',
''' val _=check"zero-is-source-minimum-sentinel"(fn()=>N.minZero 0 7=7 andalso N.minZero 9 0=9 andalso N.minZero 0 0=0)''',
'end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
print('Generated',len([x for x in lines if 'val _=check'in x]),'source/demand assertions')
