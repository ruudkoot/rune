(* Rendering is kept separate from UCD validation and the reference model. *)
structure GenerateUnicodeRender =
struct
  open GenerateUnicodeBase
  fun normal cfg directory (model:GenerateUnicodeNormal.model) checked =
    let val canonical= #canonical model
        val index=Array.array (top,~1) val ()=List.app (fn ((cp,_),i) => Array.update (index,cp,i)) (ListPair.zip (canonical,List.tabulate (length canonical,fn i => i)))
        (* A composition's first point need not itself be decomposable. *)
        val primary=let val result=ref [] in rangeEach 0 (top-1) (fn a => List.app (fn (b,cp) => result:=(a,b,cp):: !result) (Array.sub (#comp model,a)));
                sorted (fn ((a,b,_),(c,d,_)) => a<c orelse (a=c andalso b<d)) (!result) end
        fun mapping [] _ acc=List.rev acc | mapping ((cp,m)::rest) previous acc=
              mapping rest cp ((if length m>1 then List.nth (m,1) else 0)::hd m::(cp-previous)::acc)
        val qc=merge (List.mapPartial (fn (a,b,f) => if hd f="NFC_QC" then SOME (a,b,case List.nth (f,1) of "N" => 1 | "M" => 2 | _ => raise Failed "invalid NFC quick check") else NONE) (records (directory ^ "/DerivedNormalizationProps.txt")))
        val classes=List.filter (fn (_,_,v) => v<>0) (runs (fn c => Array.sub (#ccc model,c)) top)
        fun minimum xs=List.foldl Int.min (hd xs) (tl xs)
        val data=[header cfg true "The canonical decompositions, the combining classes and the quick\n   check of normalisation (lib/unicode/normalize.sml), UAX #15." ["UnicodeData.txt","CompositionExclusions.txt","DerivedNormalizationProps.txt"]] @
             beginModule cfg "UnicodeNormalizeData" @
             ["  (* no code point below the first of these has a canonical decomposition,\n     a combining class other than 0, an NFC_Quick_Check other than Yes, or\n     is the second of a primary composite: what ASCII and Latin-1 need of\n     no table *)",
              "  val firstDecomposed = 0x" ^ hx (#1 (hd canonical)),"  val firstCombining = 0x" ^ hx (#1 (hd classes)),"  val firstQuickCheck = 0x" ^ hx (#1 (hd qc)),"  val firstSecond = 0x" ^ hx (minimum (List.map #2 primary)),"",text (field "NUMBERS" cfg),
              "  (* decompositions, each written as three numbers: the distance of its\n     code point from the one before, the first code point it maps to,\n     and the second (0 where it maps to one); built as the triples code\n     point, first, second *)\n  fun decompositions (s : string) () : int vector =\n    let\n      val v = numbers s ()\n      fun go (i, prev, acc) =\n        if i >= Vector.length v then Vector.fromList (rev acc)\n        else\n          let val c = prev + Vector.sub (v, i)\n          in go (i + 3, c, Vector.sub (v, i + 2) :: Vector.sub (v, i + 1) :: c :: acc) end\n    in\n      go (0, 0, [])\n    end\n",
              numberTable "combiningClass" (deltaRanges classes) "Canonical_Combining_Class other than 0: lo, hi, class" "ranges","",
              numberTable "decomposition" (mapping canonical 0 []) "the canonical decomposition mappings, but Hangul's: code point,\n     first, second (0 for a singleton), in order of code point" "decompositions","",
              numberTable "composition" (List.map (fn (_,_,cp) => Array.sub (index,cp)) primary) "the primary composites, but Hangul's: the index in decomposition of\n     each mapping to two code points that composes again, in order of\n     first and second" "numbers","",
              numberTable "quickCheck" (deltaRanges qc) "NFC_Quick_Check: lo, hi, 1 for No, 2 for Maybe" "ranges","end",""]
        val summary="ccc " ^ Int.toString (length classes) ^ " ranges, decomposition " ^ Int.toString (length canonical) ^ ", composition " ^ Int.toString (length primary) ^ ", quick check " ^ Int.toString (length qc) ^ " ranges; NormalizationTest " ^ Int.toString checked ^ " lines checked"
    in (String.concatWith "\n" data,summary) end
  fun widths cfg directory =
    let val categories=records (directory ^ "/DerivedGeneralCategory.txt")
        val emoji=records (directory ^ "/emoji-data.txt")
        fun select names rows=List.mapPartial (fn (a,b,f) => if List.exists (fn name => name=hd f) names then SOME (a,b,0) else NONE) rows
        val zero=subtract (select ["Mn","Me","Cf"] categories) [(0xAD,0xAD)] @ [(0x1160,0x11FF,0),(0xD7B0,0xD7FF,0)]
        val control=select ["Cc"] categories
        val wide=subtract (merge (select ["W","F"] (records (directory ^ "/EastAsianWidth.txt")) @ select ["Emoji_Presentation"] emoji)) (List.map (fn (a,b,_) => (a,b)) (merge zero))
        val data=[header cfg false "The display widths of code points (lib/unicode/display_width.sml)." ["DerivedGeneralCategory.txt","EastAsianWidth.txt","emoji-data.txt"]] @ beginModule cfg "UnicodeWidthData" @
              [text (field "ONCE" cfg),vector "zero" (pairs (merge zero)) "nonspacing, enclosing and format marks; conjoining jamo","",vector "control" (pairs (merge control)) "the control characters, C0 and C1","",vector "wide" (pairs (merge wide)) "East Asian Wide and Fullwidth, and emoji presentation","end",""]
    in (String.concatWith "\n" data,[length (merge zero),length (merge control),length (merge wide)]) end
  fun graphemes cfg directory =
    let val gcb=List.map text (array (field "GCB" cfg)) val incb=List.map text (array (field "INCB" cfg))
        fun index names value=let fun loop [] _=raise Failed ("unknown Unicode property " ^ value) | loop (first::rest) i=if first=value then i else loop rest (i+1) in loop names 0 end
        val breaks=merge (List.map (fn (a,b,f) => (a,b,index gcb (hd f))) (records (directory ^ "/GraphemeBreakProperty.txt")))
        val pict=merge (List.mapPartial (fn (a,b,f) => if hd f="Extended_Pictographic" then SOME (a,b,0) else NONE) (records (directory ^ "/emoji-data.txt")))
        val conj=merge (List.mapPartial (fn (a,b,f) => if hd f="InCB" then SOME (a,b,index incb (List.nth (f,1))) else NONE) (records (directory ^ "/DerivedCoreProperties.txt")))
        fun labels names=ListPair.map (fn (name,i) => Int.toString i ^ " " ^ name) (names,List.tabulate (length names,fn i => i))
        val names=labels gcb
        val rows=List.tabulate (3,fn group => String.concatWith ", " (List.filter (fn s => s<>"") (ListPair.map (fn (label,i) => if i div 5=group then label else "") (names,List.tabulate (length names,fn i => i)))))
        val data=[header cfg false "The properties of grapheme clusters (lib/unicode/grapheme.sml)." ["GraphemeBreakProperty.txt","emoji-data.txt","DerivedCoreProperties.txt"]] @ beginModule cfg "UnicodeGraphemeData" @
             [text (field "ONCE" cfg),"  (* Grapheme_Cluster_Break, a value of each range:\n     " ^ String.concatWith "\n     " rows ^ " *)",vector "breakProperty" (triples breaks) "lo, hi, value","",vector "pictographic" (pairs pict) "Extended_Pictographic","", "  (* Indic_Conjunct_Break: " ^ String.concatWith ", " (labels incb) ^ " *)",vector "conjunct" (triples conj) "lo, hi, value","end",""]
    in (String.concatWith "\n" data,[length breaks,length pict,length conj]) end
  (* The general categories and the simple case mappings of code points
     (lib/unicode/code_point.sml, D21 of docs/plans/language/haskell98.md).
     The categories come from DerivedGeneralCategory.txt and the mappings
     from UnicodeData.txt, whose categories tests/lib/unicode/code_point.sml
     reads instead, so that two files of the UCD check each other. *)
  fun codePoints cfg directory =
    let val names=List.map text (array (field "CATEGORIES" cfg))
        fun index name=let fun loop [] _=raise Failed ("unknown Unicode general category " ^ name) | loop (x::xs) i=if x=name then i else loop xs (i+1) in loop names 0 end
        val unassigned=index "Cn"
        val ()=need (length names=30 andalso unassigned=29,"the general categories are 30, Cn the last")
        val category=Array.array (top,unassigned)
        val ()=List.app (fn (a,b,f) => rangeEach a b (fn c => Array.update (category,c,index (hd f)))) (records (directory ^ "/DerivedGeneralCategory.txt"))
        val ranges=List.filter (fn (_,_,v) => v<>unassigned) (runs (fn c => Array.sub (category,c)) top)
        val latin1=String.implode (List.tabulate (256,fn c => Char.chr (48+Array.sub (category,c))))
        (* fields 12 to 14 of UnicodeData.txt; an empty titlecase is the
           uppercase (UAX #44, 5.3), and a mapping to the code point itself
           is no mapping *)
        val upper=ref [] val lower=ref [] val title=ref []
        fun mapping s=if s="" then NONE else SOME (hex s)
        fun add c (r,SOME m)=if m<>c then r:=(c,m):: !r else () | add _ (_,NONE)=()
        val ()=List.app (fn (c,c',f) =>
              let val ()=need (c=c' andalso length f=14,"invalid UnicodeData.txt record at " ^ hx c)
                  val u=mapping (List.nth (f,11)) val l=mapping (List.nth (f,12))
                  val t=case mapping (List.nth (f,13)) of NONE => u | t => t
              in add c (upper,u);add c (lower,l);add c (title,t) end) (records (directory ^ "/UnicodeData.txt"))
        (* runs lo, hi, step, d of mappings c to c + d, the code points
           step apart, step 1 or 2 *)
        fun caseRuns pairs =
          let fun loop [] acc=List.rev acc
                | loop ((c,m)::rest) []=loop rest [(c,c,1,m-c)]
                | loop ((c,m)::rest) ((lo,hi,step,d)::acc)=
                    if m-c=d andalso (c-hi=step orelse (lo=hi andalso c-hi=2)) then loop rest ((lo,c,c-hi,d)::acc)
                    else loop rest ((c,c,1,m-c)::(lo,hi,step,d)::acc)
          in loop (sorted (fn ((a,_),(b,_)) => a<b) pairs) [] end
        fun zigzag d=if d>=0 then 2*d else ~2*d-1
        fun encode rows =
          let fun loop [] _ acc=List.rev acc | loop ((lo,hi,step,d)::rest) next acc=
                   (need (lo>=next andalso hi>=lo,"overlapping Unicode case runs");loop rest (hi+1) (zigzag d::step::(hi-lo)::(lo-next)::acc))
          in loop rows 0 [] end
        val (ups,lows,titles)=(caseRuns (!upper),caseRuns (!lower),caseRuns (!title))
        val labels=ListPair.map (fn (name,i) => Int.toString i ^ " " ^ name) (names,List.tabulate (length names,fn i => i))
        val rows=List.tabulate (3,fn group => String.concatWith ", " (List.take (List.drop (labels,10*group),10)))
        val data=[headerBy "bin/rune-generate unicode" cfg true "The general categories and the simple case mappings of code points\n   (lib/unicode/code_point.sml)." ["DerivedGeneralCategory.txt","UnicodeData.txt"]] @ beginModule cfg "UnicodeCodePointData" @
             [text (field "NUMBERS" cfg),
              "  (* runs of case mappings, each written as four numbers: the distance of\n     its first code point from the end of the run before it, the distance\n     to its last, the step between its code points (1 or 2), and the\n     distance d of each code point's mapping from it, written as 2 d, or\n     as ~2 d - 1 where d is below 0; built as the quadruples lo, hi, step,\n     d *)\n  fun runs (s : string) () : int vector =\n    let\n      val v = numbers s ()\n      fun distance e = if e mod 2 = 0 then e div 2 else ~ ((e + 1) div 2)\n      fun go (i, next, acc) =\n        if i >= Vector.length v then Vector.fromList (rev acc)\n        else\n          let\n            val lo = next + Vector.sub (v, i)\n            val hi = lo + Vector.sub (v, i + 1)\n          in\n            go (i + 4, hi + 1, distance (Vector.sub (v, i + 3)) :: Vector.sub (v, i + 2) :: hi :: lo :: acc)\n          end\n    in\n      go (0, 0, [])\n    end\n",
              "  (* General_Category, a value of each code point:\n     " ^ String.concatWith ",\n     " rows ^ " *)","",
              stringTable "latin1" latin1 "the value of each code point below 0x100, as the character \"0\" plus\n     the value","",
              numberTable "category" (deltaRanges ranges) "the values other than Cn's: lo, hi, value" "ranges","",
              numberTable "upper" (encode ups) "Simple_Uppercase_Mapping where it is not the code point itself" "runs","",
              numberTable "lower" (encode lows) "Simple_Lowercase_Mapping where it is not the code point itself" "runs","",
              numberTable "title" (encode titles) "Simple_Titlecase_Mapping where it is not the code point itself" "runs","end",""]
        fun count r=Int.toString (length (!r))
        val summary="general category " ^ Int.toString (length ranges) ^ " ranges; simple case mappings: upper " ^ count upper ^ " in " ^ Int.toString (length ups) ^ " runs, lower " ^ count lower ^ " in " ^ Int.toString (length lows) ^ " runs, title " ^ count title ^ " in " ^ Int.toString (length titles) ^ " runs"
    in (String.concatWith "\n" data,summary) end
end
