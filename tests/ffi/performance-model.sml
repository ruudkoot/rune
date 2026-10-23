(* Pure validation and distribution rules shared by the measurement driver. *)
structure FfiPerformanceModel =
struct
  fun need(condition,message)=if condition then () else raise Fail message
  fun number value=Json.Number(String.translate(fn #"~"=>"-" | c=>str c)(Real.toString value))
  fun field name value=case Json.member(name,value) of SOME v=>v | NONE=>raise Fail("missing " ^ name)
  fun text(Json.String value)=value | text _=raise Fail "expected text"
  fun integer(Json.Number value)=valOf(Int.fromString value) | integer _=raise Fail "expected count"
  fun real(Json.Number value)=valOf(Real.fromString value) | real _=raise Fail "expected number"
  fun optional name row=case Json.member(name,row) of NONE=>NONE | SOME Json.Null=>NONE | SOME value=>SOME(real value)
  fun checkRow row=
    let val phase=text(field "phase" row) val count=integer(field "iterations" row)
        val expected=if phase="scalar" orelse phase="callback" orelse phase="loop" then SOME count
          else if phase="marshal-256" then SOME(count mod 256)
          else if phase="scalar-first" orelse phase="callback-first" orelse phase="marshal-256-first" then SOME 1
          else if String.isPrefix "load-symbol" phase orelse String.isPrefix "prepare" phase then SOME 0 else NONE
        val cpu=real(field "cpuSeconds" row)
        val ()=need(count>0 andalso Real.isFinite cpu andalso cpu>=0.0,"invalid measurement")
        val ()=case optional "wallSeconds" row of NONE=>() | SOME value=>need(Real.isFinite value andalso value>=0.0,"invalid wall measurement")
        val ()=case expected of NONE=>() | SOME value=>need(text(field "checksum" row)=Int.toString value,"independent checksum mismatch")
        val ()=case Json.member("foreignResourcesBefore",row) of NONE=>() | SOME initialResources=>
          need(initialResources=field "foreignResourcesAfter" row,"phase changed native resource count")
        val ()=List.app(fn key=>case optional key row of NONE=>() | SOME value=>need(value>=0.0,"negative counter delta"))
          ["smlAllocatedBytes","smlAllocatedObjects","collections"]
        val payload=if String.isPrefix "marshal-256" phase then 256 else 0
        val ()=need(integer(field "bufferPayloadAllocatedBytes" row)=count*payload andalso
          integer(field "peakBufferPayloadBytes" row)=payload,"buffer payload accounting mismatch")
    in () end
  fun expectedPhases wanted measured=
    let val actual=List.map(fn row=>text(field "phase" row))measured
    in need(length actual=length wanted andalso List.all(fn phase=>List.exists(fn value=>value=phase)actual)wanted,"missing, duplicate or unexpected phases") end
  fun insert x []=[x] | insert x (y::ys)=if x<y then x::y::ys else y::insert x ys
  fun distribution []=Json.Null | distribution values=
    let val ordered=List.foldl(fn(x,xs)=>insert x xs)[]values val count=length values
        fun rank p=List.nth(ordered,Int.max(0,Real.ceil(p*Real.fromInt count)-1))
        val median=if count mod 2=1 then List.nth(ordered,count div 2) else
          (List.nth(ordered,count div 2-1)+List.nth(ordered,count div 2))/2.0
    in Json.Object[("count",Json.int count),("min",number(hd ordered)),("p25",number(rank 0.25)),("median",number median),
      ("p75",number(rank 0.75)),("p95",number(rank 0.95)),("max",number(List.last ordered))] end
end
