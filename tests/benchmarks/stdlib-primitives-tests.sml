structure PrimitiveTests =
struct
  structure K=BenchStdlibPrimitives
  fun read path=let val f=TextIO.openIn path val line=valOf(TextIO.inputLine f)
    val _=TextIO.closeIn f in String.substring(line,0,String.size line-1)end
  val _=T.check("stdlib/source/array_iter/smoke",fn()=>K.runArray "array_iter"["16","64"]=read "array_iter-smoke.expected")
  val _=T.check("stdlib/source/array_iter/normal",fn()=>K.runArray "array_iter"["1000","10000"]=read "array_iter-normal.expected")
  val _=T.check("stdlib/source/array_iter/large",fn()=>K.runArray "array_iter"["10000","10000"]=read "array_iter-large.expected")
  val _=T.check("stdlib/source/array_forall/smoke",fn()=>K.runArray "array_forall"["16","64"]=read "array_forall-smoke.expected")
  val _=T.check("stdlib/source/array_forall/normal",fn()=>K.runArray "array_forall"["1000","10000"]=read "array_forall-normal.expected")
  val _=T.check("stdlib/source/array_forall/large",fn()=>K.runArray "array_forall"["10000","10000"]=read "array_forall-large.expected")
  val _=T.check("stdlib/source/array_fold/smoke",fn()=>K.runArray "array_fold"["16","64"]=read "array_fold-smoke.expected")
  val _=T.check("stdlib/source/array_fold/normal",fn()=>K.runArray "array_fold"["1000","10000"]=read "array_fold-normal.expected")
  val _=T.check("stdlib/source/array_fold/large",fn()=>K.runArray "array_fold"["10000","10000"]=read "array_fold-large.expected")
  val _=T.check("stdlib/source/pervasives_compare_lists/smoke",fn()=>K.runComparison "pervasives_compare_lists"["64"]=read "pervasives_compare_lists-smoke.expected")
  val _=T.check("stdlib/source/pervasives_compare_lists/normal",fn()=>K.runComparison "pervasives_compare_lists"["100000"]=read "pervasives_compare_lists-normal.expected")
  val _=T.check("stdlib/source/pervasives_compare_lists/large",fn()=>K.runComparison "pervasives_compare_lists"["1000000"]=read "pervasives_compare_lists-large.expected")
  val _=T.check("stdlib/source/pervasives_compare_ints/smoke",fn()=>K.runComparison "pervasives_compare_ints"["64"]=read "pervasives_compare_ints-smoke.expected")
  val _=T.check("stdlib/source/pervasives_compare_ints/normal",fn()=>K.runComparison "pervasives_compare_ints"["100000"]=read "pervasives_compare_ints-normal.expected")
  val _=T.check("stdlib/source/pervasives_compare_ints/large",fn()=>K.runComparison "pervasives_compare_ints"["1000000"]=read "pervasives_compare_ints-large.expected")
  val _=T.check("stdlib/source/pervasives_compare_floats/smoke",fn()=>K.runComparison "pervasives_compare_floats"["64"]=read "pervasives_compare_floats-smoke.expected")
  val _=T.check("stdlib/source/pervasives_compare_floats/normal",fn()=>K.runComparison "pervasives_compare_floats"["100000"]=read "pervasives_compare_floats-normal.expected")
  val _=T.check("stdlib/source/pervasives_compare_floats/large",fn()=>K.runComparison "pervasives_compare_floats"["1000000"]=read "pervasives_compare_floats-large.expected")
  val _=T.check("stdlib/source/pervasives_compare_strings/smoke",fn()=>K.runComparison "pervasives_compare_strings"["64"]=read "pervasives_compare_strings-smoke.expected")
  val _=T.check("stdlib/source/pervasives_compare_strings/normal",fn()=>K.runComparison "pervasives_compare_strings"["100000"]=read "pervasives_compare_strings-normal.expected")
  val _=T.check("stdlib/source/pervasives_compare_strings/large",fn()=>K.runComparison "pervasives_compare_strings"["1000000"]=read "pervasives_compare_strings-large.expected")
  val _=T.check("stdlib/source/pervasives_equal_ints/smoke",fn()=>K.runComparison "pervasives_equal_ints"["64"]=read "pervasives_equal_ints-smoke.expected")
  val _=T.check("stdlib/source/pervasives_equal_ints/normal",fn()=>K.runComparison "pervasives_equal_ints"["100000"]=read "pervasives_equal_ints-normal.expected")
  val _=T.check("stdlib/source/pervasives_equal_ints/large",fn()=>K.runComparison "pervasives_equal_ints"["1000000"]=read "pervasives_equal_ints-large.expected")
  val _=T.check("stdlib/array-empty-fold",fn()=>K.runArray "array_fold"["0","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-singleton-fold",fn()=>K.runArray "array_fold"["1","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-zero-repeats",fn()=>K.runArray "array_iter"["16","0"]="0:0:0:0:0")
  val _=T.check("stdlib/array-empty-forall",fn()=>K.runArray "array_forall"["0","3"]="3:0:0:3:0")
  val _=T.check("stdlib/array-iter-assertion",fn()=>
    ((K.arrayOperation "array_iter"(Array.fromList[1,999])1;false)handle Fail _=>true))
  val _=T.check("stdlib/array-forall-assertion",fn()=>
    ((K.arrayOperation "array_forall"(Array.fromList[1,999])1;false)handle Fail _=>true))
  val _=T.check("stdlib/array-forall-short-circuit",fn()=>
    let val visited=ref []
        val result=K.arrayForAll(fn n=>(visited:=n:: !visited;if n=999 then raise Fail "unused"else n<2))
          (Array.fromList[1,2,999])
    in not result andalso List.rev(!visited)=[1,2]end)
  val _=T.check("stdlib/array-invalid-initialization-rejected",fn()=>
    ((K.validateArray(Array.array(4,0));false)handle Fail _=>true))
  val _=T.check("stdlib/compare-list-prefix",fn()=>K.compareList([1],[1,2])= ~1 andalso K.compareList([1,2],[1])=1)
  val _=T.check("stdlib/compare-list-equal",fn()=>K.compareList([1,2],[1,2])=0)
  val _=T.check("stdlib/integer-pivot",fn()=>List.map(K.comparison "pervasives_compare_ints")[41,42,43]=[~1,0,1])
  val _=T.check("stdlib/float-pivot",fn()=>List.map(K.comparison "pervasives_compare_floats")[4,5,6]=[~1,0,1])
  val _=T.check("stdlib/immediate-int-equality",fn()=>List.map(K.comparison "pervasives_equal_ints")[41,42,43]=[0,1,0])
  val _=T.check("stdlib/modular-observer-wrap",fn()=>K.render(K.summarize 2(fn _=> ~1))="2:FFFFFFFE:2:0:0")
  val _=T.check("stdlib/invalid-length",fn()=>((K.runArray "array_fold"["10001","1"];false)handle Fail _=>true))
  val _=T.check("stdlib/invalid-count",fn()=>((K.runComparison "pervasives_compare_ints"["1000001"];false)handle Fail _=>true))
  val _=T.check("stdlib/negative-count",fn()=>((K.runComparison "pervasives_compare_ints"["~1"];false)handle Fail _=>true))
end
