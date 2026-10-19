(* Source selector scopes and loop bounds from Sandmark hashtbl_bench.ml. *)
structure BenchStdlibHashtblPrograms=
struct
 structure H=BenchStdlibHashtbl
 structure Hash=BenchStdlibHash
 val seed=0wx811C9DC5:Word32.word
 fun mix h n=Word32.*(Word32.xorb(h,n),0w16777619)
 fun loop first last f=if first>last then()else(f first;loop(first+1)last f)
 (* Main constructs these empty tables once before dispatch. Find selectors
  * do not call their sibling replace closure and therefore search empty tables. *)
 val genericTable:int H.table=H.create H.Generic 2000
 val integerTable:int H.table=H.create H.Integer 2000
 fun populated()=
   let val h=H.create H.Generic 1000
       val _=loop 1 1000(fn i=>H.add h i i)
   in h end
 fun reject valid=if valid then()else raise Fail"incorrect result: stdlib hashtable"
 fun checkRange table lower upper copies=
   let val seen=Array.array(Int.max(0,upper-lower+1),0)
       val _=H.iter(fn key=>fn value=>
         (reject(key>=lower andalso key<=upper andalso value=key);
          Array.update(seen,key-lower,Array.sub(seen,key-lower)+1)))table
       val _=loop 0(Array.length seen-1)(fn i=>reject(Array.sub(seen,i)=copies))
   in reject(H.length table=Array.length seen*copies)end
 fun digest table=H.fold(fn key=>fn value=>fn state=>
   Word32.+(state,Word32.+(Word32.fromInt key,Word32.fromInt value)))table 0w0
 val modulus=IntInf.pow(2,63)
 val sign=IntInf.pow(2,62)
 fun double value=
   let val next=IntInf.mod(IntInf.*(value,IntInf.fromInt 2),modulus)
   in if IntInf.>=(next,sign)then IntInf.-(next,modulus)else next end
 fun low32 value=Word32.fromLargeInt value
 fun run name iterations=
   let val sum=ref seed
       fun observe n=sum:=mix(!sum)n
       fun intClosures table replacing=
         loop 0 iterations(fn _=>
          if replacing then
            (loop 0 999(fn i=>H.replace table i i);checkRange table 0 999 1;observe 0w1000)
          else let val seen=ref 0
               val _=loop 0 999(fn i=>(reject(H.findOpt table i=NONE);seen:= !seen+1))
               val _=reject(H.length table=0)
             in observe(Word32.fromInt(!seen))end)
       val _=case name of
          "int_replace1"=>intClosures genericTable true
         |"int_replace2"=>intClosures integerTable true
         |"int_find1"=>intClosures genericTable false
         |"int_find2"=>intClosures integerTable false
         |"caml_hash_int"=>loop 0 iterations(fn _=>
            loop 0 999(fn i=>observe(Word32.fromInt(Hash.integer i))))
         |"caml_hash_tuple"=>loop 0 iterations(fn _=>
            loop 0 999(fn i=>observe(Word32.fromInt(Hash.pair(i,i)))))
         |"hashtbl_iter"=>let val table=populated()
             in loop 1 iterations(fn _=>let val visits=ref 0
                val _=H.iter(fn key=>fn value=>(reject(key=value);visits:= !visits+1))table
                val _=reject(!visits=1000)
              in observe(Word32.fromInt(!visits))end)end
         |"hashtbl_fold"=>let val table=populated()
             in loop 1 iterations(fn _=>let val total=H.fold(fn key=>fn value=>fn total=>key+value+total)table 0
              val _=reject(total=1001000)
              in observe(Word32.fromInt total)end)end
         |"hashtbl_add_resizing"=>let val table=H.create H.Generic 1
             val _=loop 1 iterations(fn i=>H.add table i i)
             val _=checkRange table 1 iterations 1
             in observe(digest table)end
         |"hashtbl_add_sized"=>let val table=H.create H.Generic iterations
             val _=loop 1 iterations(fn i=>H.add table i i)
             val _=checkRange table 1 iterations 1
             in observe(digest table)end
         |"hashtbl_add_duplicate"=>let val table=H.create H.Generic 1
             val _=loop 1 iterations(fn i=>(H.add table i i;H.add table i i))
             val _=checkRange table 1 iterations 2
             in observe(digest table)end
         |"hashtbl_remove"=>loop 1(iterations div 1000+1)(fn _=>
              let val table=populated()
                  val _=loop 1 1000(fn i=>H.remove table i)
                  val _=reject(H.length table=0)
              in observe(digest table)end)
         |"hashtbl_find"=>let val table=populated()
             in loop 1 iterations(fn i=>
               let val actual=H.findOpt table i
                   val _=reject(actual=(if i<=1000 then SOME i else NONE))
               in observe(case actual of NONE=>0w0|SOME value=>Word32.fromInt value)end)end
         |"hashtbl_filter_map"=>
             let val table=H.create H.Generic 1000
                 val _=loop 1 1000(fn i=>H.add table i(IntInf.fromInt i))
                 val _=loop 1 iterations(fn _=>H.filterMap(fn _=>fn v=>SOME(double v))table)
                 fun expected i=
                   let val bits=Int.min(iterations,63)
                       val scaled=IntInf.mod(IntInf.*(IntInf.fromInt i,IntInf.pow(2,bits)),modulus)
                   in if IntInf.>=(scaled,sign)then IntInf.-(scaled,modulus)else scaled end
                 val _=reject(H.length table=1000)
                 val total=H.fold(fn key=>fn value=>fn state=>
                   (reject(key>=1 andalso key<=1000 andalso value=expected key);
                    Word32.+(state,Word32.+(Word32.fromInt key,low32 value)) ))table 0w0
             in observe total end
         |_=>raise Fail"unknown hashtable selector"
   in Int.toString iterations^":"^Word32.toString(!sum)end
end
