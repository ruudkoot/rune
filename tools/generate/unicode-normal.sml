(* Independent normalizer constructed from the raw UCD. Generated runtime
   tables are never used to decide whether their own regeneration is valid. *)
structure GenerateUnicodeNormal =
struct
  open GenerateUnicodeBase
  type model={ccc:int array,dec:(bool*int list) array,comp:(int*int) list array,canonical:(int*int list) list}
  fun readModel directory : model =
    let val ccc=Array.array (top,0) val dec=Array.array (top,(false,[])) val canonical=ref [] : (int*int list) list ref
        val stream=TextIO.openIn (directory ^ "/UnicodeData.txt")
        fun loop ()=case TextIO.inputLine stream of NONE => () | SOME line =>
          let val cols=fields #";" (String.translate (fn #"\n" => "" | c => str c) line) val cp=hex (hd cols)
              val ()=Array.update (ccc,cp,integer (List.nth (cols,3)))
              val parts=String.tokens Char.isSpace (List.nth (cols,5))
              val compat=not (null parts) andalso String.isPrefix "<" (hd parts)
              val mapping=List.map hex (if compat then tl parts else parts)
              val ()=Array.update (dec,cp,(compat,mapping))
          in if null mapping orelse compat then () else canonical:=(cp,mapping):: !canonical;loop () end
        val ()=loop () val ()=TextIO.closeIn stream
        val excluded=Word8Array.array (top,0w0)
        val ()=List.app (fn (a,b,_) => rangeEach a b (fn c => Word8Array.update (excluded,c,0w1))) (records (directory ^ "/CompositionExclusions.txt"))
        val ()=List.app (fn (cp,m) => if length m=1 orelse Array.sub (ccc,cp)<>0 orelse Array.sub (ccc,hd m)<>0 then Word8Array.update (excluded,cp,0w1) else ()) (!canonical)
        val derived=Word8Array.array (top,0w0)
        val ()=List.app (fn (a,b,f) => if hd f="Full_Composition_Exclusion" then rangeEach a b (fn c => Word8Array.update (derived,c,0w1)) else ()) (records (directory ^ "/DerivedNormalizationProps.txt"))
        val ()=rangeEach 0 (top-1) (fn c => need (Word8Array.sub (excluded,c)=Word8Array.sub (derived,c),"Full_Composition_Exclusion differs at " ^ hx c))
        val comp=Array.array (top,[]) : (int*int) list array
        val ()=List.app (fn (cp,m) => if Word8Array.sub (excluded,cp)<>0w0 then () else case m of [a,b] => Array.update (comp,a,(b,cp)::Array.sub (comp,a)) | _ => raise Failed "nonbinary primary composition") (!canonical)
    in {ccc=ccc,dec=dec,comp=comp,canonical=List.rev (!canonical)} end
  fun normalize (m:model) form cps =
    let val compat=form="NFKC" orelse form="NFKD"
        fun decompose cp =
          if cp>=0xAC00 andalso cp<0xAC00+11172 then
             let val i=cp-0xAC00 in [0x1100+i div 588,0x1161+(i mod 588) div 28] @ (if i mod 28=0 then [] else [0x11A7+i mod 28]) end
          else case Array.sub (#dec m,cp) of (isCompat,mapping) => if null mapping orelse (isCompat andalso not compat) then [cp] else List.concat (List.map decompose mapping)
        fun cc cp=Array.sub (#ccc m,cp)
        fun reorder cps =
          let fun flush run acc=List.revAppend (sorted (fn (a,b) => cc a<cc b) (List.rev run),acc)
              fun loop [] run acc=List.rev (flush run acc)
                | loop (c::rest) run acc=if cc c<>0 then loop rest (c::run) acc else loop rest [] (c::flush run acc)
          in loop cps [] [] end
        val decomposed=reorder (List.concat (List.map decompose cps))
    in if form="NFD" orelse form="NFKD" orelse null decomposed then decomposed else
       let val result=Array.array (length decomposed,0) val count=ref 1
           val first=hd decomposed val ()=Array.update (result,0,first)
           val starter=ref (if cc first=0 then SOME 0 else NONE) val previous=ref (if isSome (!starter) then 0 else 256)
           fun one c=
             let val cl=cc c
                 val composite=case !starter of NONE => NONE | SOME i =>
                   if not (!previous<cl orelse (!previous=0 andalso !count-1=i)) then NONE else
                     let val s=Array.sub (result,i)
                     in if s>=0x1100 andalso s<0x1100+19 andalso c>=0x1161 andalso c<0x1161+21 then SOME (0xAC00+((s-0x1100)*21+c-0x1161)*28)
                        else if s>=0xAC00 andalso s<0xAC00+11172 andalso (s-0xAC00) mod 28=0 andalso c>0x11A7 andalso c<0x11A7+28 then SOME (s+c-0x11A7)
                        else Option.map #2 (List.find (fn (b,_) => b=c) (Array.sub (#comp m,s))) end
             in case composite of SOME c => Array.update (result,valOf (!starter),c)
               | NONE => (if cl=0 then starter:=SOME (!count) else ();previous:=cl;Array.update (result,!count,c);count:= !count+1) end
           val ()=List.app one (tl decomposed)
       in List.tabulate (!count,fn i => Array.sub (result,i)) end end
  fun check model directory =
    let val input=List.filter (not o String.isPrefix "@") (load (directory ^ "/NormalizationTest.txt"))
        fun one line=
          let val cols=List.map (List.map hex o String.tokens Char.isSpace) (List.take (fields #";" line,5))
              fun test form indexes expected=List.app (fn i => need (normalize model form (List.nth (cols,i))=List.nth (cols,expected),"reference normalizer fails NormalizationTest")) indexes
          in test "NFC" [0,1,2] 1;test "NFC" [3,4] 3;test "NFD" [0,1,2] 2;test "NFD" [3,4] 4;test "NFKC" [0,1,2,3,4] 3;test "NFKD" [0,1,2,3,4] 4 end
    in List.app one input;length input end
end
