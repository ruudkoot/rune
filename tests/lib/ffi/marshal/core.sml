(* libraries: test/unit *)
structure ForeignMarshalTests =
struct
  fun test name condition=Test.it name(fn()=>Expect.that(name,condition()))
  fun number s=valOf(IntInf.fromString s)
  fun encode width signed little value=ForeignBytes.integer{width=width,signed=signed,littleEndian=little,value=value}
  fun decode signed little bytes=ForeignBytes.value{signed=signed,littleEndian=little,bytes=bytes}
  val integers=List.map(fn(width,signed,n)=>test("integer " ^ Int.toString width ^ "/" ^ Bool.toString signed ^ "/" ^ n)
    (fn()=>List.all(fn little=>decode signed little (encode width signed little(number n))=number n)[true,false]))
    [(1,true,"~128"),(1,true,"127"),(1,false,"255"),(2,true,"~32768"),(2,true,"32767"),(2,false,"65535"),
     (4,true,"~2147483648"),(4,true,"2147483647"),(4,false,"4294967295"),
     (8,true,"~9223372036854775808"),(8,true,"9223372036854775807"),(8,false,"18446744073709551615"),
     (16,true,"~170141183460469231731687303715884105728"),(16,true,"170141183460469231731687303715884105727"),
     (16,false,"340282366920938463463374607431768211455")]
  val ranges=List.map(fn(width,signed,n)=>test("range " ^ Int.toString width ^ "/" ^ n)(fn()=>
    ((ignore(encode width signed true(number n));false)handle ForeignBytes.Error _=>true)))
    [(0,false,"0"),(17,false,"0"),(1,true,"128"),(1,true,"~129"),(1,false,"256"),(1,false,"~1"),
     (8,false,"18446744073709551616"),(8,true,"9223372036854775808")]
  fun text encoding little terminated input=ForeignText.encode{encoding=encoding,littleEndian=little,terminated=terminated,text=input}
  fun native encoding little terminated input=ForeignText.decode{encoding=encoding,littleEndian=little,terminated=terminated,bytes=input}
  val texts=List.map(fn input=>test("UTF-16 round trip " ^ String.toString input)(fn()=>List.all(fn little=>
    native ForeignText.Utf16 little true(text ForeignText.Utf16 little true input)=input)[true,false]))
    ["","ASCII","caf\195\169","\226\130\172","\240\159\152\128","\237\160\128","\237\191\191",
     "a\237\160\128z","\237\176\128\237\160\128"]
  val malformed=["\192\128","\193\191","\128","\226\130","\240\128\128\128","\244\144\128\128","\245\128\128\128","\237\160\000"]
  val invalid=List.map(fn input=>test("reject malformed UTF-8 " ^ Int.toString(Char.ord(String.sub(input,0))))(fn()=>
    List.all(fn encoding=>((ignore(text encoding true false input);false)handle ForeignText.Error _=>true))
      [ForeignText.Utf8,ForeignText.Wtf8,ForeignText.Utf16]))malformed
  val tests=Test.describe "ffi/marshal"(integers @ ranges @ texts @ invalid @
    [test "every byte round trips"(fn()=>List.all(fn i=>let val n=IntInf.fromInt i
      in decode false true(encode 1 false true n)=n andalso decode false false(encode 1 false false n)=n end)(List.tabulate(256,fn i=>i))),
     test "big endian native bytes"(fn()=>encode 4 false false 16909060="\001\002\003\004"),
     test "little endian native bytes"(fn()=>encode 4 false true 16909060="\004\003\002\001"),
     test "signed native bytes"(fn()=>encode 2 true true ~2="\254\255"),
     test "empty integer rejected"(fn()=>((ignore(decode false true "");false)handle ForeignBytes.Error _=>true)),
     test "binary64 independent bytes"(fn()=>ForeignBytes.real64{littleEndian=false,value=1.0}="\063\240\000\000\000\000\000\000"),
     test "binary64 negative zero"(fn()=>Real.signBit(ForeignBytes.real64Value{littleEndian=true,
       bytes=ForeignBytes.real64{littleEndian=true,value= ~0.0}})),
     test "binary64 count rejected"(fn()=>((ignore(ForeignBytes.real64Value{littleEndian=true,bytes="\000"});false)handle ForeignBytes.Error _=>true)),
     test "bytes preserve embedded zero"(fn()=>native ForeignText.Bytes true false(text ForeignText.Bytes true false "a\000b")="a\000b"),
     test "terminated bytes reject embedded zero"(fn()=>((ignore(text ForeignText.Bytes true true "a\000b");false)handle ForeignText.Error{offset,...}=>offset=1)),
     test "UTF-8 rejects lone surrogate"(fn()=>((ignore(text ForeignText.Utf8 true false "\237\160\128");false)handle ForeignText.Error _=>true)),
     test "UTF-16 high surrogate bytes"(fn()=>text ForeignText.Utf16 true false "\237\160\128"="\000\216"),
     test "UTF-16 low surrogate bytes"(fn()=>text ForeignText.Utf16 false false "\237\176\128"="\220\000"),
     test "UTF-16 astral pair bytes"(fn()=>text ForeignText.Utf16 true false "\240\159\152\128"="\061\216\000\222"),
     test "UTF-16 pair normalizes to scalar UTF-8"(fn()=>native ForeignText.Utf16 true false "\061\216\000\222"="\240\159\152\128"),
     test "termination bounds byte text"(fn()=>((ignore(native ForeignText.Bytes true true "abc");false)handle ForeignText.Error _=>true)),
     test "termination bounds wide text"(fn()=>((ignore(native ForeignText.Utf16 true true "a\000");false)handle ForeignText.Error _=>true)),
     test "wide terminator is a code unit"(fn()=>native ForeignText.Utf16 true true "\000\001\000\000"="\196\128"),
     test "odd UTF-16 rejected"(fn()=>((ignore(native ForeignText.Utf16 true false "a");false)handle ForeignText.Error _=>true)),
     test "terminated text ignores bytes after terminator"(fn()=>native ForeignText.Utf8 true true "a\000\255"="a"),
     test "cleanup order"(fn()=>let val trace=ref []
       val answer=ForeignScope.withScope(fn scope=>(List.app(fn i=>ignore(ForeignScope.defer(scope,fn()=>trace:=i:: !trace)))[1,2,3];42))
       in answer=42 andalso !trace=[1,2,3] end),
     test "all cleanup attempted after failures"(fn()=>let val trace=ref []
       val failed=((ForeignScope.withScope(fn scope=>List.app(fn i=>ignore(ForeignScope.defer(scope,fn()=>(trace:=i:: !trace;raise Fail(Int.toString i)))))[1,2,3]);false)
         handle Fail message=>message="3")
       in failed andalso !trace=[1,2,3] end),
     test "body exception survives cleanup exception"(fn()=>
       ((ForeignScope.withScope(fn scope=>(ignore(ForeignScope.defer(scope,fn()=>raise Fail "cleanup"));raise Fail "body"));false)
         handle Fail message=>message="body")),
     test "early cleanup at most once"(fn()=>let val count=ref 0
       val ()=ForeignScope.withScope(fn scope=>let val ticket=ForeignScope.defer(scope,fn()=>count:= !count+1)
         in ForeignScope.run ticket;ForeignScope.run ticket end)
       in !count=1 end),
     test "failed early cleanup at most once"(fn()=>let val count=ref 0
       val ()=ForeignScope.withScope(fn scope=>let val ticket=ForeignScope.defer(scope,fn()=>(count:= !count+1;raise Fail "cleanup"))
         in (ForeignScope.run ticket handle Fail _=>());ForeignScope.run ticket end)
       in !count=1 end),
     test "cancel transfers cleanup"(fn()=>let val count=ref 0
       val ()=ForeignScope.withScope(fn scope=>ForeignScope.cancel(ForeignScope.defer(scope,fn()=>count:= !count+1)))
       in !count=0 end),
     test "closed scope rejects registration"(fn()=>let val saved=ForeignScope.withScope(fn scope=>scope)
       in ((ignore(ForeignScope.defer(saved,fn()=>()));false)handle ForeignScope.Closed=>true) end)])
end
structure ForeignMarshalMain=Main(struct val name="ffi/marshal" val tests=ForeignMarshalTests.tests end)
val ()=ForeignMarshalMain.main()
