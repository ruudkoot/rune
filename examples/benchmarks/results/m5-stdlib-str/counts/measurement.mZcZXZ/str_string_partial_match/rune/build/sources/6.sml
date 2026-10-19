(* The exact nonempty literal Str fragment required by the six stdlib cases.
 * Reuse the suite matcher; preserve source call scopes and match-result state.
 * OCaml 4.14.1 Str sources and notices accompany the import. *)
structure BenchStdlibStr=
struct
 structure R=BenchRegexReduxStr
 structure P=BenchStdlibTextPrograms
 val pattern="Novum Site"
 val text=BenchStdlibTextInput.text
 val last=ref(Vector.fromList([]:int list))
 fun save result=
   case result of NONE=>(last:=Vector.fromList[];false)
   |SOME(first,finish)=>(last:=Vector.fromList[first,finish];true)
 fun stringMatch regex input start=
   case R.match false regex input start of NONE=>save NONE
   |SOME finish=>save(SOME(start,finish))
 fun search regex input start=
   case R.search false regex input start of NONE=>(save NONE;NONE)
   |SOME pair=>(save(SOME pair);SOME pair)
 (* Partial matching is restricted to the benchmark's literal sequences. *)
 fun partial regex input start=
   let val n=String.size input
       fun one [] i=SOME i
         |one(R.Literal c::rest)i=
            if i=n then SOME i
            else if String.sub(input,i)=c then one rest(i+1)else NONE
         |one _ _=raise Fail"unsupported partial regex fragment"
       fun alternatives []=NONE
         |alternatives(first::rest)=case one first start of NONE=>alternatives rest|some=>some
   in if start<0 orelse start>n then raise Subscript
      else case alternatives regex of NONE=>save NONE|SOME finish=>save(SOME(start,finish))end
 fun replace regex replacement input=
   let val n=String.size input
       fun loop start chunks=case search regex input start of
         NONE=>String.concat(rev(String.substring(input,start,n-start)::chunks))
       |SOME(first,finish)=>if first=finish then raise Fail"empty Str replacement unsupported"
          else loop finish(replacement::String.substring(input,start,first-start)::chunks)
   in loop 0[]end
 fun split regex input=
   let val n=String.size input
       val start=if stringMatch regex input 0 then Vector.sub(!last,1)else 0
       fun progress start=case search regex input start of NONE=>NONE
         |SOME(first,finish)=>if finish>start then SOME(first,finish)
           else if start<n then progress(start+1)else NONE
       fun loop start chunks=if start>=n then rev chunks
         else case progress start of NONE=>rev(String.substring(input,start,n-start)::chunks)
           |SOME(first,finish)=>loop finish(String.substring(input,start,first-start)::chunks)
   in loop start[]end
 fun literalText[atoms]=
   String.implode(List.map(fn R.Literal c=>c|_=>raise Fail"incorrect result: nonliteral regex")atoms)
   |literalText _=raise Fail"incorrect result: regex alternatives"
 datatype value=Regex of R.regexp|Truth of bool|Position of int|Text of string|Parts of string list
 fun check name value=
   let val valid=case(name,value)of
      ("str_regexp",Regex regex)=>literalText regex=pattern
     |("str_string_match",Truth b)=>not b
     |("str_string_partial_match",Truth b)=>not b
     |("str_search_forward",Position i)=>i=274
     |("str_global_replace",Text output)=>
        output=String.substring(text,0,274)^"."^String.extract(text,284,NONE)
     |("str_split",Parts parts)=>parts=[text]
     |_=>false
   in if valid then()else raise Fail"incorrect result: stdlib Str value"end
 fun hash value=case value of
    Regex regex=>P.hashString(literalText regex)
   |Truth b=>if b then 0w1 else 0w0
   |Position i=>Word32.fromInt i
   |Text text=>P.hashString text
   |Parts words=>P.hashValue(P.Parts words)
 fun operation name=
   if name="str_regexp"then fn()=>Regex(R.compile pattern)
   else let val regex=R.compile(if name="str_split"then"@"else pattern)
    in case name of
      "str_string_match"=>(fn()=>Truth(stringMatch regex text 0))
     |"str_string_partial_match"=>(fn()=>Truth(partial regex text 0))
     |"str_search_forward"=>(fn()=>Position(case search regex text 0 of NONE=>raise Fail"search missing"|SOME(i,_)=>i))
     |"str_global_replace"=>(fn()=>Text(replace regex "." text))
     |"str_split"=>(fn()=>Parts(split regex text))
     |_=>raise Fail"unknown Str selector"end
 fun run name count=
   let val step=operation name
       fun loop i state=if i>count then state
         else let val value=step()val _=check name value
              in loop(i+1)(P.mix state(hash value))end
   in Int.toString count^":"^Word32.toString(loop 1 P.seed)end
end
