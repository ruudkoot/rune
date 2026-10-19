(* Paul Hudak's mailing-label page/block layout and append-file work. *)
structure Benchmark =
struct
  val name = "maillist"
  fun file path =
    let val input = TextIO.openIn path
        val text = TextIO.inputAll input
        val _ = TextIO.closeIn input
    in text end
  fun lines text = if text="" then [] else
    let val parts = String.fields(fn c => c= #"\n")text
    in if String.sub(text,String.size text-1)= #"\n" then List.take(parts,List.length parts-1) else parts end
  fun blank line = List.all(fn c => c= #" " orelse c= #"\t")(String.explode line)
  fun paras [] = []
    | paras lines =
        let fun split [] reversed = (List.rev reversed,[])
              | split (line::rest) reversed = if blank line then (List.rev reversed,line::rest)
                  else split rest (line::reversed)
            fun drop [] = [] | drop (line::rest) = if blank line then drop rest else line::rest
            val (entry,rest) = split lines []
        in entry :: paras(drop rest) end
  fun append path text =
    let val output = TextIO.openAppend path
        val _ = TextIO.output(output,text)
    in TextIO.closeOut output end
  fun convert input path =
    let
      val longWarnings = ref 0
      val truncated = ref 0
      val output = TextIO.openOut path
      val _ = TextIO.output(output,"% Latex Mailing List.\n\n\\input{labels.sty}\n\n\\begin{document}\n\n")
      val _ = TextIO.closeOut output
      fun entry rows =
        let fun loop [] n = if n<5 then loop(List.tabulate(5-n,fn _ => ""))n else ()
              | loop(line::rest)n = if n>4 then truncated := !truncated+1 else
                  (append path line;append path "\\\\ ";
                   if String.size line>35 then longWarnings := !longWarnings+1 else ();
                   loop rest (n+1))
        in loop rows 1 end
      fun block entries kind size =
        let val _ = append path kind
            fun loop [] n = loop(List.tabulate(size-n+1,fn _ => []))n
              | loop(first::rest)n =
                  (entry first;
                   if n=size then (append path "\n}}\n";rest)
                   else (append path "\n}{\n";loop rest(n+1)))
        in loop entries 1 end
      fun pages [] = append path "\n\\end{document}\n"
        | pages entries =
            let val _ = append path "\\lpage\n"
                val a = block entries "{\\lblock{\n" 9
                val b = block a "{\\lblock{\n" 9
                val c = block b "{\\lblock{\n" 9
                val rest = block c "{\\sblock{\n" 3
            in pages rest end
      val _ = pages(paras(lines input))
    in (!longWarnings,!truncated) end
  fun run [path,repetitions,reference] =
    let val times = BenchInput.between(1,100)(BenchInput.integer repetitions)
        val expected = file reference
        fun loop 0 bytes warnings = IntInf.toString bytes ^ ":" ^ Int.toString warnings
          | loop left bytes warnings =
              let val (long,truncated) = convert(file path) "output.tex"
                  val actual = file "output.tex"
                  val _ = if actual=expected then () else raise Fail "mailing-label output differs"
              in loop(left-1)(IntInf.+(bytes,IntInf.fromInt(String.size actual)))(warnings+long+truncated) end
    in loop times 0 0 end
    | run _ = raise Fail "maillist expects input repetitions reference"
end
