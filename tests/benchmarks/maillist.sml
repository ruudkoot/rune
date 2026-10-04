structure BenchMaillistTests =
struct
  val header = "% Latex Mailing List.\n\n\\input{labels.sty}\n\n\\begin{document}\n\n"
  val footer = "\n\\end{document}\n"
  val emptyLabel = "\\\\ \\\\ \\\\ \\\\ "
  fun label rows = String.concat(List.map(fn row => row ^ "\\\\ ") rows)
  fun block kind rows = kind ^ String.concatWith "\n}{\n" rows ^ "\n}}\n"
  fun page labels = "\\lpage\n" ^
    block "{\\lblock{\n" (List.take(labels,9)) ^
    block "{\\lblock{\n" (List.take(List.drop(labels,9),9)) ^
    block "{\\lblock{\n" (List.take(List.drop(labels,18),9)) ^
    block "{\\sblock{\n" (List.drop(labels,27))
  fun padded labels = labels @ List.tabulate(30-List.length labels,fn _ => emptyLabel)
  fun output input expected counts =
    Benchmark.convert input "labels-test.tex" = counts andalso
    Benchmark.file "labels-test.tex" = expected
  val _ = T.check("maillist/line-endings",fn () =>
    Benchmark.lines "" = [] andalso Benchmark.lines "A\n\n" = ["A",""] andalso
    Benchmark.lines "A\r\nB" = ["A\r","B"])
  val _ = T.check("maillist/blank-paragraphs",fn () =>
    Benchmark.paras ["","\t ","A","","","B"] = [[],["A"],["B"]])
  val _ = T.check("maillist/empty-document",fn () => output "" (header ^ footer) (0,0))
  val _ = T.check("maillist/one-label-padding",fn () =>
    output "A\nB\n" (header ^ page(padded[label["A","B","",""]]) ^ footer) (0,0))
  val _ = T.check("maillist/leading-blank-label",fn () =>
    output "\n\t\nA\n" (header ^ page(padded[emptyLabel,label["A","","",""]]) ^ footer) (0,0))
  val _ = T.check("maillist/four-line-truncation",fn () =>
    output "A\nB\nC\nD\nE\nF\n" (header ^ page(padded[label["A","B","C","D"]]) ^ footer) (0,1))
  val _ = T.check("maillist/long-line-boundary",fn () =>
    let val a = String.implode(List.tabulate(35,fn _ => #"x"))
        val b = a ^ "y"
    in output (a ^ "\n" ^ b ^ "\n")
         (header ^ page(padded[label[a,b,"",""]]) ^ footer) (1,0) end)
  val _ = T.check("maillist/page-boundary",fn () =>
    let val entries = List.tabulate(31,fn n => Int.toString(n+1))
        val labels = List.map(fn text => label[text,"","",""]) entries
    in output (String.concatWith "\n\n" entries ^ "\n")
         (header ^ page(List.take(labels,30)) ^ page(padded[List.nth(labels,30)]) ^ footer) (0,0) end)
end
