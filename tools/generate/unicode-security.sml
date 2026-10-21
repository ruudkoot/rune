structure GenerateUnicodeSecurity =
struct
  open GenerateUnicodeBase
  fun make cfg directory =
    let val (typeNames,types)=GenerateUnicodeProfile.typeData cfg directory
        val status=Word8Array.array (top,0w0)
        val ()=List.app (fn (lo,hi,f) => if hd f="Allowed" then rangeEach lo hi (fn c => Word8Array.update (status,c,0w1)) else ()) (records (directory ^ "/IdentifierStatus.txt"))
        val ()=rangeEach 0 (top-1) (fn c => need ((Array.sub (types,c) div 4=0)=(Word8Array.sub (status,c)=0w1),"Identifier_Status differs from Identifier_Type at " ^ hx c))
        val masks=sorted (op <) (GenerateText.distinct (Array.foldl (fn (v,seen) => if List.exists (fn old => old=v) seen then seen else v::seen) [] types))
        val maskIndex=Array.array (4096,0) val ()=List.app (fn (v,i) => Array.update (maskIndex,v,i)) (ListPair.zip (masks,List.tabulate (length masks,fn i => i)))
        val typeRuns=runs (fn c => Array.sub (maskIndex,Array.sub (types,c))) top
        val aliases=ref [] : (string*string) list ref
        val ()=List.app (fn line => case List.map trim (fields #";" line) of "sc"::short::long::rest => List.app (fn name => aliases:=(name,short):: !aliases) (long::rest) | _ => ()) (load (directory ^ "/PropertyValueAliases.txt"))
        val augment=List.map (fn row => case array row of [name,values] => (text name,List.map text (array values)) | _ => raise Failed "bad augmented script rule") (array (field "AUGMENT" cfg))
        val names=sort (GenerateText.distinct (List.map #2 (!aliases) @ List.concat (List.map #2 augment)))
        val nameIndex=ListPair.zip (names,List.tabulate (length names,fn i => i))
        fun index name=case List.find (fn (key,_) => key=name) nameIndex of SOME (_,i) => i | NONE => raise Failed ("unknown Unicode script " ^ name)
        val ()=need (List.all (fn name => size name=4) names,"script short names must have four characters")
        val script=Array.array (top,index "Zzzz")
        val ()=List.app (fn (a,b,f) => let val name=case List.find (fn (name,_) => name=hd f) (!aliases) of SOME (_,v) => v | NONE => raise Failed ("missing script alias " ^ hd f)
                           val idx=index name in rangeEach a b (fn c => Array.update (script,c,idx)) end) (records (directory ^ "/Scripts.txt"))
        val ext=Array.array (top,NONE) : int list option array
        val ()=List.app (fn (a,b,f) => let val value=SOME (List.map index (String.tokens Char.isSpace (hd f)))
                           in rangeEach a b (fn c => Array.update (ext,c,value)) end) (records (directory ^ "/ScriptExtensions.txt"))
        val augment=List.map (fn (name,others) => (index name,List.map index others)) augment
        val common=index "Zyyy" val inherited=index "Zinh"
        val sets=ref [([],0)] : (int list*int) list ref val ordered=ref [[]] : int list list ref
        fun augmented items =
          if List.exists (fn i => i=common orelse i=inherited) items then [] else
           let val result=List.foldl (fn ((name,others),items) => if List.exists (fn i => i=name) items then GenerateText.distinct (items @ others) else items) (GenerateText.distinct items) augment
           in sorted (op <) result end
        fun register items =
          let val items=augmented items
          in case List.find (fn (old,_) => old=items) (!sets) of SOME (_,i) => i | NONE =>
               let val i=length (!ordered) in sets:=(items,i):: !sets;ordered:= !ordered @ [items];i end end
        val cache=Array.array (length names,~1)
        fun setOf c=case Array.sub (ext,c) of SOME items => register items | NONE =>
             let val s=Array.sub (script,c) val cached=Array.sub (cache,s)
             in if cached>=0 then cached else let val i=register [s] in Array.update (cache,s,i);i end end
        val scriptRuns=runs setOf top
        val serialized=List.concat (List.map (fn [] => [0] | values => length values::values) (!ordered))
        val (conf,keys)=GenerateUnicodeProfile.confusables directory
        fun confTable [] _ acc=List.rev acc | confTable (c::rest) previous acc =
             let val mapping=Array.sub (conf,c) in confTable rest c (List.revAppend (mapping,length mapping::(c-previous)::acc)) end
        val recommended=String.tokens Char.isSpace "Zyyy Zinh Arab Armn Beng Cyrl Deva Ethi Geor Grek Gujr Guru Hang Hani Hebr Hira Kana Knda Khmr Laoo Latn Mlym Mymr Orya Sinh Taml Telu Thaa Thai Tibt"
        val data=[header cfg true "The data of UTS #39, Unicode Security Mechanisms\n   (lib/unicode/security.sml): the identifier types of code points,\n   their augmented script sets, and the confusables." ["IdentifierType.txt","IdentifierStatus.txt","Scripts.txt","ScriptExtensions.txt","PropertyValueAliases.txt","confusables.txt"]] @ beginModule cfg "UnicodeSecurityData" @
              [text (field "NUMBERS" cfg),"  (* Identifier_Type: a mask of the bits 1 << i of these, in order *)","  val typeNames = [" ^ String.concatWith ", " (List.map GenerateFixtures.literal typeNames) ^ "]","",
               numberTable "typeMasks" masks "the masks of the sets that occur" "numbers","",numberTable "types" (deltaRanges typeRuns) "the set of each code point: lo, hi, index in typeMasks" "ranges","",
               "  (* the short names of the scripts (ISO 15924), four characters each,\n     with Hanb, Hntl, Jpan and Kore *)","  val scriptNames = \"" ^ String.concat names ^ "\"","",
               "  (* the scripts of UAX #31's Table 5, Recommended Scripts, by index in\n     scriptNames *)","  val recommended = [" ^ String.concatWith ", " (List.map (Int.toString o index) recommended) ^ "]","",
               numberTable "scriptSets" serialized "the augmented script sets that occur: the number of scripts of each\n     and their indexes in scriptNames, in order; the first is 0, for\n     the sets that hold Common or Inherited and stand for all scripts" "numbers","",
               numberTable "scripts" (deltaRanges scriptRuns) "the augmented script set of each code point: lo, hi, the index of the\n     set in scriptSets" "ranges","",
               numberTable "confusables" (confTable keys 0 []) "the confusables: the distance of each source from the one before, the\n     number of code points of its prototype, and those code points" "numbers","end",""]
        val summary="types " ^ Int.toString (length masks) ^ " sets in " ^ Int.toString (length typeRuns) ^ " ranges; " ^ Int.toString (length names) ^ " scripts, " ^ Int.toString (length (!sets)) ^ " script sets in " ^ Int.toString (length scriptRuns) ^ " ranges; " ^ Int.toString (length keys) ^ " confusables"
    in (String.concatWith "\n" data,summary) end
end
