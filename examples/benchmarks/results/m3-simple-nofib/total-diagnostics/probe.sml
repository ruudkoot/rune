structure K=BenchSimpleNofibFn(val strict=false val gridMax=100)
fun bits x=
 let val v=PackReal64Big.toBytes x
 in String.concat(List.tabulate(8,fn i=>let val h=Word8.fmt StringCvt.HEX(Word8Vector.sub(v,i))
     in if String.size h=1 then"0"^h else h end))end
val(ts,state)=K.compute 20
val(_,refs)=let val C=BenchSimpleReference.read"normal.reference"
  in case C of _::_::_::_::rest=>((),rest)|_=>raise Fail"reference"end
fun loop _ [] []=()
 |loop i(t::ts)(r::rs)=
   let val actual=BenchLazy.force t val expected=BenchSimpleReference.decode r
   in print("TOTAL\t"^Int.toString i^"\t"^bits actual^"\t"^bits expected^"\t"^r^"\n");
      loop(i+1)ts rs end
 |loop _ _ _=raise Fail"totals count"
val _=loop 0 ts refs
val _=List.app(fn(name,a)=>
 let val total=List.foldl(fn(z,s)=>s+Real.abs(K.A.sub a z))0.0(K.A.positions(K.A.bounds a))
 in print("ABS\t"^name^"\t"^bits total^"\n")end)(K.arrays state)
