functor BenchSchedFn(D:BENCH_SUSPEND)=
struct
 structure F=BenchIdaFiniteFn(D)
 structure L=BenchLazy
 datatype defNode=EmptyDef|JobDef of int D.t*int D.t*int D.t*defNode D.t*defNode D.t
 type definition=defNode D.t
 datatype statNode=EmptyStat|JobStat of int D.t*int D.t*int D.t*int D.t*definition
 type status=statNode D.t
 datatype procNode=Proc of int D.t*status
 type processor=procNode D.t
 type jobs=statNode F.seq
 type processors=procNode F.seq
 datatype treeNode=Leaf of int L.delay|Branch of treeNode L.delay*treeNode L.delay
 type tree=treeNode L.delay
 datatype 'a pairNode=Pair of 'a D.t*'a D.t
 type 'a pair='a pairNode D.t
 datatype 'a sandwarg=Sandwarg of 'a*int L.delay
 fun value x=D.delay(fn()=>x)
 fun defer f=D.delay(fn()=>D.force(f()))
 fun pair a b=D.delay(fn()=>Pair(D.delay a,D.delay b))
 fun first p=case D.force p of Pair(a,_)=>D.force a
 fun second p=case D.force p of Pair(_,b)=>D.force b
 fun emptyDef()=value EmptyDef
 fun emptyStat()=value EmptyStat
 fun job id fork join left right=D.delay(fn()=>JobDef(value id,value fork,value join,left,right))
 fun defId d=case D.force d of JobDef(id,_,_,_,_)=>D.force id|_=>raise Fail"empty job definition"
 fun defFork d=case D.force d of JobDef(_,steps,_,_,_)=>D.force steps|_=>raise Fail"empty job definition"
 fun defJoin d=case D.force d of JobDef(_,_,steps,_,_)=>D.force steps|_=>raise Fail"empty job definition"
 fun defLeft d=case D.force d of JobDef(_,_,_,child,_)=>child|_=>raise Fail"empty job definition"
 fun defRight d=case D.force d of JobDef(_,_,_,_,child)=>child|_=>raise Fail"empty job definition"
 fun isEmptyDef d=case D.force d of EmptyDef=>true|_=>false
 fun stat mark steps owner parent definition=D.delay(fn()=>JobStat(mark,steps,owner,parent,definition))
 fun isEmptyStat s=case D.force s of EmptyStat=>true|_=>false
 fun mark s=case D.force s of JobStat(m,_,_,_,_)=>D.force m|_=>raise Fail"empty job status"
 fun steps s=case D.force s of JobStat(_,n,_,_,_)=>D.force n|_=>raise Fail"empty job status"
 fun owner s=case D.force s of JobStat(_,_,p,_,_)=>D.force p|_=>raise Fail"empty job status"
 fun parent s=case D.force s of JobStat(_,_,_,p,_)=>D.force p|_=>raise Fail"empty job status"
 fun definition s=case D.force s of JobStat(_,_,_,_,d)=>d|_=>raise Fail"empty job status"
 fun procCell id state=D.delay(fn()=>Proc(id,state))
 fun proc id state=procCell(value id)state
 fun procId p=case D.force p of Proc(id,_)=>D.force id
 fun procStatus p=case D.force p of Proc(_,state)=>state
 fun null xs=case D.force xs of F.Nil=>true|_=>false
 fun head xs=case D.force xs of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail xs=case D.force xs of F.Nil=>raise Empty|F.Cons(_,xs)=>xs
 fun addChild definition parentCell=D.delay(fn()=>
   if isEmptyDef definition then EmptyStat
   else if defFork definition=0 then
     D.force(stat(value 4)(D.delay(fn()=>defJoin definition))(value 0)parentCell definition)
   else D.force(stat(value 1)(D.delay(fn()=>defFork definition))(value 0)parentCell definition))
 fun anyJob fresh old pid=D.delay(fn()=>case D.force fresh of
      F.Nil=>D.force(pair(fn()=>old)(fn()=>F.empty()))
     |F.Cons(state,rest)=>
       if isEmptyStat state orelse mark state=1 orelse
          (mark state=4 andalso(owner state=D.force pid orelse owner state=0))
       then D.force(pair(fn()=>old)(fn()=>F.cons(state,rest)))
       else D.force(anyJob rest(F.cons(state,old))pid))
 fun minZero 0 x=x|minZero x 0=x|minZero x y=if x<y then x else y
 fun minimumCycle procs=case D.force procs of F.Nil=>0
   |F.Cons(p,rest)=>if isEmptyStat(procStatus p)then minimumCycle rest
       else minZero(steps(procStatus p))(minimumCycle rest)
 fun perform procs duration=D.delay(fn()=>case D.force procs of
      F.Nil=>D.force(pair(fn()=>F.empty())(fn()=>F.empty()))
     |F.Cons(p,rest)=>
       let val shared=perform rest duration
           val state=procStatus p
           val pid=D.delay(fn()=>procId p)
       in if isEmptyStat state then
           D.force(pair(fn()=>first shared)(fn()=>F.cons(procCell pid(emptyStat()),second shared)))
          else if steps state=duration then
           D.force(pair(fn()=>F.cons(procCell pid(stat(D.delay(fn()=>mark state))(value 0)
               (D.delay(fn()=>owner state))(D.delay(fn()=>parent state))(definition state)),first shared))
             (fn()=>F.cons(procCell pid(emptyStat()),second shared)))
          else D.force(pair(fn()=>first shared)
             (fn()=>F.cons(procCell pid(stat(D.delay(fn()=>mark state))(D.delay(fn()=>steps state-duration))
               (D.delay(fn()=>owner state))(D.delay(fn()=>parent state))(definition state)),second shared)))
       end)
 fun acknowledge target jobs=D.delay(fn()=>case D.force jobs of
      F.Nil=>F.Nil
     |F.Cons(state,rest)=>
       if D.force target=defId(definition state)then
         D.force(F.cons(stat(D.delay(fn()=>mark state+1))(D.delay(fn()=>steps state))
           (D.delay(fn()=>owner state))(D.delay(fn()=>parent state))(definition state),rest))
       else D.force(F.cons(state,acknowledge target rest)))
 fun addJobs completed jobs=F.defer(fn()=>case D.force completed of
      F.Nil=>jobs
     |F.Cons(p,rest)=>
       let val state=procStatus p
           val d=definition state
       in if mark state=1 then
            F.cons(stat(value 2)(D.delay(fn()=>defJoin d))(D.delay(fn()=>procId p))(D.delay(fn()=>parent state))d,
              F.cons(addChild(defer(fn()=>defLeft d))(D.delay(fn()=>defId d)),
                F.cons(addChild(defer(fn()=>defRight d))(D.delay(fn()=>defId d)),addJobs rest jobs)))
          else addJobs rest(acknowledge(D.delay(fn()=>parent state))jobs)
       end)
 fun sandwich constructor(Sandwarg(a,_))(Sandwarg(b,_))=constructor(a,b)
 fun allocate threshold fresh procs old assigned total level=L.delay(fn()=>case D.force procs of
      F.Nil=>L.force(process threshold(F.append old fresh)assigned total level)
     |F.Cons(p,rest)=>
       if null fresh then L.force(allocate threshold old rest(F.empty())(F.cons(p,assigned))total level)
       else if not(isEmptyStat(procStatus p))then
         L.force(allocate threshold(F.append old fresh)rest(F.empty())(F.cons(p,assigned))total level)
       else
         let val pid=D.delay(fn()=>procId p)
             val choices=anyJob fresh old pid
             val firstNew=D.delay(fn()=>D.force(second choices))
         in if null firstNew then
              L.force(allocate threshold(F.append old fresh)rest(F.empty())(F.cons(p,assigned))total level)
            else let val chosen=head firstNew
                     val remaining=tail firstNew
                     val oldFirst=F.defer(fn()=>first choices)
                     val more=anyJob remaining(F.cons(chosen,oldFirst))pid
                     val moreNew=F.defer(fn()=>second more)
                     val next=level+1
                 in if null moreNew then
                      L.force(allocate threshold(F.append oldFirst remaining)rest(F.empty())
                        (F.cons(procCell pid chosen,assigned))total level)
                    else
                      let val left=allocate threshold(F.append oldFirst remaining)rest(F.empty())
                            (F.cons(procCell pid chosen,assigned))total next
                          val right=allocate threshold moreNew(F.cons(p,rest))(F.defer(fn()=>first more))assigned total next
                      in if level>=threshold then Branch(left,right)
                         else sandwich Branch(Sandwarg(left,L.delay(fn()=>2*next)))
                           (Sandwarg(right,L.delay(fn()=>2*next+1)))end
                 end
         end)
 and process threshold jobs procs total level=L.delay(fn()=>
   let val duration=minimumCycle procs
   in if duration=0 then Leaf(L.delay(fn()=>total))
      else let val shared=perform procs duration
               val completed=F.defer(fn()=>first shared)
               val pending=F.defer(fn()=>second shared)
           in L.force(allocate threshold(addJobs completed jobs)pending(F.empty())(F.empty())(total+duration)level)end
   end)
 fun optimum tree=case L.force tree of Leaf answer=>L.force answer
   |Branch(left,right)=>minZero(optimum left)(optimum right)
 val procs=F.cons(proc 1(emptyStat()),F.cons(proc 2(emptyStat()),F.empty()))
 fun schedule root threshold=allocate threshold(F.cons(addChild root(value 0),F.empty()))procs(F.empty())(F.empty())0 0
 val c_solo=job 1 0 10 (emptyDef()) (emptyDef())
 val c_job31=job 2 0 30 (emptyDef()) (emptyDef())
 val c_job32=job 3 0 10 (emptyDef()) (emptyDef())
 val c_trio=job 1 10 20 c_job31 c_job32
 val c_job74=job 4 0 38 (emptyDef()) (emptyDef())
 val c_job75=job 5 0 50 (emptyDef()) (emptyDef())
 val c_job72=job 2 19 10 c_job74 c_job75
 val c_job76=job 6 0 10 (emptyDef()) (emptyDef())
 val c_job77=job 7 0 40 (emptyDef()) (emptyDef())
 val c_job73=job 3 18 30 c_job76 c_job77
 val c_septiem=job 1 20 20 c_job72 c_job73
 val c_job1008=job 8 0 30 (emptyDef()) (emptyDef())
 val c_job1009=job 9 0 60 (emptyDef()) (emptyDef())
 val c_job1004=job 4 17 15 c_job1008 c_job1009
 val c_job1005=job 5 0 50 (emptyDef()) (emptyDef())
 val c_job1002=job 2 19 10 c_job1004 c_job1005
 val c_job1006=job 6 0 10 (emptyDef()) (emptyDef())
 val c_job1007=job 7 0 40 (emptyDef()) (emptyDef())
 val c_job1003=job 3 18 30 c_job1006 c_job1007
 val c_deciem=job 1 20 20 c_job1002 c_job1003
 val c_job1108=job 8 0 20 (emptyDef()) (emptyDef())
 val c_job1109=job 9 0 50 (emptyDef()) (emptyDef())
 val c_job1104=job 4 17 15 c_job1108 c_job1109
 val c_job1110=job 10 0 30 (emptyDef()) (emptyDef())
 val c_job1111=job 11 0 60 (emptyDef()) (emptyDef())
 val c_job1105=job 5 25 12 c_job1110 c_job1111
 val c_job1102=job 2 19 10 c_job1104 c_job1105
 val c_job1106=job 6 0 10 (emptyDef()) (emptyDef())
 val c_job1107=job 7 0 40 (emptyDef()) (emptyDef())
 val c_job1103=job 3 18 30 c_job1106 c_job1107
 val c_undeciem=job 1 20 20 c_job1102 c_job1103
 val c_job1208=job 8 0 30 (emptyDef()) (emptyDef())
 val c_job1209=job 9 0 60 (emptyDef()) (emptyDef())
 val c_job1204=job 4 17 15 c_job1208 c_job1209
 val c_job1210=job 10 0 30 (emptyDef()) (emptyDef())
 val c_job1211=job 11 0 60 (emptyDef()) (emptyDef())
 val c_job1205=job 5 25 12 c_job1210 c_job1211
 val c_job1202=job 2 19 10 c_job1204 c_job1205
 val c_job1206=job 6 0 10 (emptyDef()) (emptyDef())
 val c_job1207=job 7 0 40 (emptyDef()) (emptyDef())
 val c_job1203=job 3 18 30 c_job1206 c_job1207
 val c_duodeciem=job 1 20 20 c_job1202 c_job1203
 val c_job1412=job 12 0 28 (emptyDef()) (emptyDef())
 val c_job1413=job 13 0 50 (emptyDef()) (emptyDef())
 val c_job1402=job 2 19 10 c_job1412 c_job1413
 val c_job1407=job 7 0 40 (emptyDef()) (emptyDef())
 val c_job1406=job 6 0 10 (emptyDef()) (emptyDef())
 val c_job1409=job 9 0 60 (emptyDef()) (emptyDef())
 val c_job1408=job 8 19 10 c_job1406 c_job1409
 val c_job1404=job 4 17 15 c_job1407 c_job1408
 val c_job1410=job 10 0 30 (emptyDef()) (emptyDef())
 val c_job1411=job 11 0 60 (emptyDef()) (emptyDef())
 val c_job1405=job 5 25 12 c_job1410 c_job1411
 val c_job1403=job 3 18 30 c_job1404 c_job1405
 val c_quadrideciem=job 1 20 20 c_job1402 c_job1403
 fun input size=case size of 1=>c_solo|3=>c_trio|7=>c_septiem|10=>c_deciem|11=>c_undeciem|12=>c_duodeciem|14=>c_quadrideciem|_=>emptyDef()
 fun calculate threshold size=optimum(schedule(input size)threshold)
 fun main size=Int.toString(calculate(if size<=3 then 0 else size-3)size)^"\n"
 fun statistics tree=
   let fun mix h n=Word32.*(Word32.xorb(h,Word32.fromInt n),0w16777619)
       fun walk h tree=case L.force tree of
         Leaf n=>let val n=L.force n in(1,n,n,IntInf.fromInt n,mix h n)end
        |Branch(left,right)=>
           let val(ca,la,ha,sa,x)=walk(mix h 1)left
               val(cb,lb,hb,sb,y)=walk(mix x 2)right
           in(ca+cb,Int.min(la,lb),Int.max(ha,hb),IntInf.+(sa,sb),y)end
   in walk 0wx811C9DC5 tree end

end
