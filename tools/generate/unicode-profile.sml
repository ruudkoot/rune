(* Identifier profile and its frozen, independently seeded exclusions. *)
structure GenerateUnicodeProfile =
struct
  open GenerateUnicodeBase
  fun typeData cfg directory =
    let val names=List.map text (array (field "TYPES" cfg))
        fun index name=let fun loop [] _=raise Failed ("unknown Identifier_Type " ^ name) | loop (x::xs) i=if x=name then i else loop xs (i+1) in loop names 0 end
        fun bit 0=1 | bit n=2*bit (n-1)
        val values=Array.array (top,bit (index "Not_Character"))
        val ()=List.app (fn (lo,hi,f) => let val mask=List.foldl (fn (name,n) => n+bit (index name)) 0 (String.tokens Char.isSpace (hd f))
                      in rangeEach lo hi (fn c => Array.update (values,c,mask)) end) (records (directory ^ "/IdentifierType.txt"))
    in (names,values) end
  fun confusables directory =
    let val conf=Array.array (top,[]) : int list array val keys=ref [] : int list ref
        val ()=List.app (fn line => let val cols=fields #";" line val src=List.map hex (String.tokens Char.isSpace (hd cols))
                     val dst=List.map hex (String.tokens Char.isSpace (List.nth (cols,1)))
                     val cp=case src of [cp] => cp | _ => raise Failed "confusable source has more than one code point"
                   in Array.update (conf,cp,dst);keys:=cp:: !keys end) (load (directory ^ "/confusables.txt"))
    in (conf,sorted (op <) (!keys)) end
  fun make cfg directory model =
    let val xs=Word8Array.array (top,0w0) val xc=Word8Array.array (top,0w0) val di=Word8Array.array (top,0w0)
        val ()=List.app (fn (lo,hi,f) =>
              let val dest=case hd f of "XID_Start" => SOME xs | "XID_Continue" => SOME xc | "Default_Ignorable_Code_Point" => SOME di | _ => NONE
              in case dest of NONE => () | SOME dest => rangeEach lo hi (fn c => Word8Array.update (dest,c,0w1)) end) (records (directory ^ "/DerivedCoreProperties.txt"))
        fun has a c=Word8Array.sub (a,c)<>0w0
        val ignorable=Word8Array.array (top,0w0)
        val ()=List.app (fn row => case array row of [a,b] => rangeEach (integer (case a of Json.Number s => s | _ => "")) (integer (case b of Json.Number s => s | _ => "")) (fn c => Word8Array.update (ignorable,c,0w1)) | _ => raise Failed "bad frozen ignorable range") (array (field "FROZEN_IGNORABLE" cfg))
        val frozen=Array.array (top,~1)
        val groups=["SEEDED_PUNCTUATION","SEEDED_DIGITS","ZEROS_AND_ONES","BY_HAND"]
        fun freeze (name,i)=List.app (fn (key,ch) => let val c=integer key val value=text ch
                  in need (Array.sub (frozen,c)= ~1,"overlapping frozen Unicode lookalikes");need (c>=128 andalso has xc c andalso size value=1,"invalid frozen Unicode lookalike");Array.update (frozen,c,128*i+Char.ord (String.sub (value,0))) end) (object (field name cfg))
        val ()=List.app freeze (ListPair.zip (groups,[1,2,3,4]))
        val (_,types)=typeData cfg directory val (conf,_)=confusables directory
        val digits=Word8Array.array (top,0w0)
        val ()=List.app (fn (a,b,f) => if hd f="Nd" then rangeEach a b (fn c => Word8Array.update (digits,c,0w1)) else ()) (records (directory ^ "/DerivedGeneralCategory.txt"))
        fun skeleton c =GenerateUnicodeNormal.normalize model "NFD" (List.concat (List.map (fn cp => if has di cp then [] else case Array.sub (conf,cp) of [] => [cp] | mapping => mapping) (GenerateUnicodeNormal.normalize model "NFD" [c])))
        val punctuation=text (field "SML_PUNCTUATION" cfg)
        val validateSeed=text (field "VERSION" cfg)=text (field "SEED_VERSION" cfg)
        fun check c =
          let val expected=Array.sub (frozen,c) val category=if expected<0 then 0 else expected div 128
              val s=if c>=128 andalso has xc c andalso Array.sub (types,c) mod 2=0 then skeleton c else []
              val ascii=case s of [cp] => if cp<128 then SOME (Char.chr cp) else NONE | _ => NONE
              val actual=case ascii of NONE => ~1 | SOME ch =>
                  if Char.contains punctuation ch then 128+Char.ord ch
                  else if Char.isDigit ch then 256+Char.ord ch
                  else if (ch = #"O" orelse ch = #"l") andalso has digits c andalso category<>4 then 384+(if ch = #"O" then Char.ord #"0" else Char.ord #"1") else ~1
              val ()=if validateSeed then
                  (need ((if category=4 then ~1 else expected)=actual,"frozen Unicode seed differs at " ^ hx c);
                   need (has ignorable c=(has xc c andalso has di c),"frozen default ignorables differ at " ^ hx c)) else ()
          in if category=4 then need ((c=0xB7 andalso expected mod 128=Char.ord #".") orelse (ascii=SOME #"l" andalso expected mod 128=Char.ord #"|"),"invalid hand-selected Unicode lookalike") else () end
        val ()=rangeEach 0 (top-1) check
        fun excluded c=has ignorable c orelse Array.sub (frozen,c)>=0
        fun value c=if not (has xc c) then 0 else if excluded c then 3 else if has xs c then 2 else 1
        fun maximum i=if i<0 then raise Failed "empty identifier profile" else if value i=1 orelse value i=2 then i else maximum (i-1)
        val limit=(maximum (top-1) div 128+1)*128
        val blocks=ref [] : (string*int) list ref val ordered=ref [] : string list ref
        fun block b=
          let val block=String.implode (List.tabulate (128,fn i => Char.chr (value (128*b+i))))
          in case List.find (fn (old,_) => old=block) (!blocks) of SOME (_,i) => i | NONE =>
               let val i=length (!blocks) in blocks:=(block,i):: !blocks;ordered:= !ordered @ [block];i end end
        val stage1=List.tabulate (limit div 128,block)
        val ()=need (length (!blocks)<=256,"identifier profile has more than 256 blocks")
        val stage2=String.concat (List.map (fn block => String.concat (List.tabulate (64,fn i => hx (4*Char.ord (String.sub (block,2*i))+Char.ord (String.sub (block,2*i+1)))))) (!ordered))
        val look=merge (List.mapPartial (fn (key,ch) => SOME (integer key,integer key,Char.ord (String.sub (text ch,0)))) (List.concat (List.map (object o (fn name => field name cfg)) groups)))
        val data=[header cfg true "The properties of identifiers (lib/unicode/identifier.sml): UAX #31's\n   XID_Start and XID_Continue, the default ignorables, and the profile\n   of docs/plans/utf8.md (D10) that leaves out the default ignorables\n   and the lookalikes of Standard ML's punctuation and digits that\n   scripts/gen-unicode-tables.py freezes." ["DerivedCoreProperties.txt"]] @ beginModule cfg "UnicodeIdentifierData" @
             [text (field "NUMBERS" cfg),"  (* The profile, as a table of two stages: the value of a code point c\n     below limit is the 2 bits at c mod block of the block numbered by\n     the two hexadecimal digits at 2 (c div block) of stage1, in stage2,\n     where each hexadecimal digit holds two values, the first in its\n     high bits. 0 is not XID_Continue, 1 XID_Continue but not\n     XID_Start, 2 XID_Start, 3 XID_Continue but left out of the profile;\n     above limit, 3 in beyond and 0 elsewhere. *)","  val block = 128","  val limit = 0x" ^ hx limit,"",
              stringTable "stage1" (String.concat (List.map (StringCvt.padLeft #"0" 2 o hx) stage1)) "the block of each 128 code points","",stringTable "stage2" stage2 "the blocks, 128 values of 2 bits each","",
              numberTable "beyond" (deltaRanges (spans (fn c => c>=limit andalso has xc c))) "XID_Continue at or above limit: lo, hi, 1" "ranges","",
              numberTable "startLeftOut" (deltaRanges (spans (fn c => excluded c andalso has xs c))) "the code points left out of the profile that are XID_Start: lo, hi, 1" "ranges","",
              numberTable "defaultIgnorable" (deltaRanges (spans (has di))) "Default_Ignorable_Code_Point: lo, hi, 1" "ranges","",
              numberTable "lookalikes" (deltaRanges look) "the lookalikes, frozen: lo, hi, the code of the ASCII character\n     they look like" "ranges","end",""]
        fun count a=Word8Array.foldl (fn (b,n) => if b=0w0 then n else n+1) 0 a
        val sizes=List.map (length o object o (fn name => field name cfg)) groups
        val summary="XID_Start " ^ Int.toString (count xs) ^ ", XID_Continue " ^ Int.toString (count xc) ^ ", Default_Ignorable " ^ Int.toString (count di) ^ "; frozen: ignorable " ^ Int.toString (count ignorable) ^ ", lookalikes " ^ Int.toString (List.foldl (op +) 0 sizes) ^
             " (" ^ Int.toString (List.nth (sizes,0)) ^ " punctuation, " ^ Int.toString (List.nth (sizes,1)) ^ " digits 2 to 9, " ^ Int.toString (List.nth (sizes,2)) ^ " digits 0 and 1, " ^ Int.toString (List.nth (sizes,3)) ^ " by hand); profile " ^ Int.toString (length (!blocks)) ^ " blocks of 128 below 0x" ^ hx limit
    in (String.concatWith "\n" data,summary) end
end
