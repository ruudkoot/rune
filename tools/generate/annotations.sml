structure GenerateAnnotations =
struct
  open MeasureCommon
  fun host config =
    let val kind=hd (fields #":" config)
        val rest=case GenerateText.splitAt ":" config of SOME (_,rest) => rest | NONE => config
        val (name,version)=case GenerateText.splitAt "@" rest of SOME pair => pair | NONE => (rest,"*")
        val (label,bits)=case name of "mlton" => ("MLton","") | "polyml" => ("Poly/ML","") | "smlnj*" => ("SML/NJ","")
          | "smlnj-legacy" => ("SML/NJ"," (64-bit)") | "smlnj32" => ("SML/NJ"," (32-bit)")
          | "smlnj-dev" => ("SML/NJ development","") | "smlnj-dev*" => ("SML/NJ development","")
          | "mlkit" => ("MLKit","") | "*" => ("MLton, SML/NJ, Poly/ML, MLKit","") | _ => ("?","")
    in if kind="rune" orelse kind="xc1" orelse kind="xc2" then "" else if label="?" then "?" else label ^ (if version="*" then "" else " " ^ version) ^ bits end
  val head="# What other implementations of the Basis Library do differently, by the label\n# of the check that shows it. Made by tests/basis/gen-annotations.sh from\n# tests/basis/deviations.txt; do not edit. The format is that of\n# `runedoc --annotations` (docs/doc-comments.md):\n#   label-glob | whom it is about | text\n@title Other implementations\n@intro what the test suite of the library finds MLton, SML/NJ, Poly/ML and MLKit to do differently, under the members whose checks show it. A remark that names a version is known of that version only; docs/basis-compat.md has the versions that were compared and the comparison as a whole.\n"
  fun main args =
    let val (check,destination)=case args of [] => (false,"annotations.txt") | ["--check"] => (true,"annotations.txt") | ["--out",path] => (false,path) | _ => raise Usage "annotations [--check | --out FILE]"
        val base=fromRoot "tests/basis" val target=if OS.Path.isAbsolute destination then destination else base ^ "/" ^ destination
        fun row (line,i)=let val cells=fields #"|" line
            in case cells of rawConfig::rawLabel::rawCategory::reason =>
                 let val config=trim rawConfig val label=trim rawLabel val category=trim rawCategory
                 in if List.exists (fn c => c=category) ["WIDTH","XC1-NA","XC2-NA","HOST-FLAKY"] orelse String.isPrefix "@" label orelse
                      List.exists (fn p => String.isPrefix p label) ["PrimIO.","StreamIO.","ImperativeIO."] then NONE else
                   let val who=host config val reason=trim (String.concatWith "|" reason)
                   in if who="" then NONE else if who="?" then raise Failed ("deviations.txt:" ^ Int.toString i ^ ": unknown configuration " ^ config) else
                     let val text=case category of "HOST-BUG" => reason | "HOST-ABSENT" => "not there: " ^ reason
                          | "SPEC-AMBIGUOUS" => "another reading of the specification: " ^ reason
                          | _ => raise Failed ("deviations.txt:" ^ Int.toString i ^ ": unknown category " ^ category)
                   in SOME (label ^ " | " ^ who ^ " | " ^ text) end end end
              | _ => raise Failed ("deviations.txt:" ^ Int.toString i ^ ": not four fields") end
        val source=String.fields (fn c => c = #"\n") (GenerateText.required (base ^ "/deviations.txt"))
        val rows=List.mapPartial (fn (line,i) => if trim line="" orelse String.isPrefix "#" (trim line) then NONE else row (line,i)) (ListPair.zip (source,List.tabulate (length source,fn i => i+1)))
        val rows=GenerateText.distinct rows val content=head ^ String.concat (List.map (fn s => s ^ "\n") rows)
        val count=Int.toString (length (List.filter (fn line => not (String.isPrefix "#" line orelse String.isPrefix "@" line)) (lines (read (base ^ "/annotations.txt")))))
    in if check then (need (read target=content,"tests/basis/annotations.txt is not what deviations.txt gives (run rune-generate annotations, then make docs)");say ("gen-annotations: annotations.txt is up to date (" ^ count ^ " annotations)\n"))
       else (GenerateText.atomic target content;say ("gen-annotations: wrote " ^ destination ^ " (" ^ count ^ " annotations)\n"));0 end
end
