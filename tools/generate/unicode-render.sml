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
end
