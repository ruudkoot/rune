structure BenchStdlibTreePrograms=
struct
 structure M=BenchStdlibIntMap
 structure S=BenchStdlibIntSet
 fun for first last f=if first>last then()else(f first;for(first+1)last f)
 fun mapEntries size=
   let fun build n entries=if n<0 then entries else build(n-1)((n,n)::entries)
   in build(size-1)[]end
 fun denseMapEntries entries=List.foldl(fn((k,v),m)=>M.add k v m)M.Empty entries
 fun denseMap size=denseMapEntries(mapEntries size)
 fun initialSet size=let fun add n tree=if n<=0 then tree else add(n-1)(S.add n tree)
   in add size S.Empty end
 fun checkMap count scale tree=
   let val seen=ref 0
       val _=M.iter(fn k=>fn v=>
         if k>=0 andalso k<count andalso v=scale*k then seen:= !seen+1
         else raise Fail"incorrect result: map contents")tree
   in if !seen=count then()else raise Fail"incorrect result: map cardinality"end
 fun mapDigest tree=M.fold(fn k=>fn v=>fn sum=>Word32.+(sum,Word32.fromInt(k+v)))tree 0w0
 fun setDigest tree=S.fold(fn k=>fn sum=>Word32.+(sum,Word32.fromInt k))tree 0w0
 fun mapBindingsRange first last tree=
   let val next=ref first
       val _=M.iter(fn k=>fn v=>if k= !next andalso v=k then next:= !next+1
         else raise Fail"incorrect result: map range")tree
   in if !next=last+1 then()else raise Fail"incorrect result: map range length"end
 fun mapRun name baseline iterations=
   let val size=10000
       fun checkScalar operation expected=
         let val sum=ref(0w0:Word32.word)
             val _=for 1 iterations(fn i=>let val result=operation i
               in if result=expected i then sum:=Word32.+(!sum,Word32.fromInt result)
                  else raise Fail"incorrect result: map operation"end)
         in Word32.toString(!sum)end
   in case name of
       "map_iter"=>checkScalar(fn _=>let val seen=ref 0
          val _=M.iter(fn k=>fn v=>if k=v then seen:= !seen+1 else raise Fail"incorrect result: iter")baseline
         in !seen end)(fn _=>size)
     |"map_fold"=>checkScalar(fn _=>M.fold(fn c=>fn k=>fn v=>c+k+v)baseline 0)(fn _=>99990000)
     |"map_for_all"=>checkScalar(fn _=>if M.forAll(fn k=>fn v=>k<size andalso v<size)baseline then 1 else 0)(fn _=>1)
     |"map_find"=>checkScalar(fn i=>case M.find i baseline of NONE=>0|SOME v=>
          if v=i then 1 else raise Fail"incorrect result: find")(fn i=>if i<size then 1 else 0)
     |"map_map"=>
        let val sum=ref(0w0:Word32.word)
            val _=for 1 iterations(fn _=>let val mapped=M.map(fn value=>2*value)baseline
              val _=checkMap size 2 mapped in sum:=Word32.+(!sum,mapDigest mapped)end)
        in Word32.toString(!sum)end
     |"map_add"=>
        let val _=if Option.isSome(M.find size baseline)then raise Fail"source map assertion"else()
            fun add 0 tree=tree|add n tree=add(n-1)(M.add n n tree)
            val result=add iterations M.Empty val _=mapBindingsRange 1 iterations result
        in Word32.toString(mapDigest result)end
     |"map_add_duplicate"=>
        let fun add 0 tree=tree|add n tree=add(n-1)(M.add n n(M.add n n tree))
            val result=add iterations M.Empty val _=mapBindingsRange 1 iterations result
        in Word32.toString(mapDigest result)end
     |"map_remove"=>
        let fun remove 0 tree=if M.isEmpty tree then baseline else tree
              |remove n tree=let val current=if M.isEmpty tree then baseline else tree
                  val(key,_)=M.minimum baseline
                in remove(n-1)(M.remove key current)end
            val result=remove iterations baseline
            val _=mapBindingsRange(if iterations=0 then 0 else 1)(size-1)result
        in Word32.toString(mapDigest result)end
     |_=>raise Fail"unknown map operation"end
 fun setRun name iterations=
   let val size=1000 val baseline=initialSet size
       fun checkScalar operation expected=
         let val sum=ref(0w0:Word32.word)
             val _=for 1 iterations(fn i=>let val result=operation i
               in if result=expected i then sum:=Word32.+(!sum,Word32.fromInt result)
                 else raise Fail"incorrect result: set operation"end)
         in Word32.toString(!sum)end
   in case name of
       "set_fold"=>checkScalar(fn _=>S.fold(fn c=>fn acc=>c+acc)baseline 0)(fn _=>500500)
     |"set_mem"=>checkScalar(fn i=>if S.member i baseline then 1 else 0)(fn i=>if i<=size then 1 else 0)
     |"set_add_rem"=>
       let fun update 0 tree=tree|update n tree=update(n-1)(S.remove n(S.add n tree))
           val result=update iterations baseline
           val expected=List.tabulate(Int.max(0,size-iterations),fn i=>iterations+i+1)
           val _=if S.elements result=expected then()else raise Fail"incorrect result: add/rem"
       in Word32.toString(setDigest result)end
     |_=>raise Fail"unknown set operation"end
end
