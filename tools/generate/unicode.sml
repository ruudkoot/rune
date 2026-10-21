structure GenerateUnicode =
struct
  open GenerateUnicodeBase
  fun main args =
    let fun parse cache output []=(cache,output)
          | parse cache _ ("--out-root"::path::rest)=parse cache (OS.Path.mkAbsolute {path=path,relativeTo=OS.FileSys.getDir ()}) rest
          | parse _ output (path::rest)=if String.isPrefix "-" path then raise Usage "unicode [UCD_DIR] [--out-root DIR]" else parse (OS.Path.mkAbsolute {path=path,relativeTo=OS.FileSys.getDir ()}) output rest
        val (directory,output)=parse (fromRoot "build/ucd") root args val cfg=config () val ()=fetch cfg directory
        val model=GenerateUnicodeNormal.readModel directory val checked=GenerateUnicodeNormal.check model directory
        val (width,wcounts)=GenerateUnicodeRender.widths cfg directory
        val (graph,gcounts)=GenerateUnicodeRender.graphemes cfg directory
        val (normal,normalSummary)=GenerateUnicodeRender.normal cfg directory model checked
        val (ident,identSummary)=GenerateUnicodeProfile.make cfg directory model
        val (security,securitySummary)=GenerateUnicodeSecurity.make cfg directory
        val outputs=[("width_data.sml",width),("grapheme_data.sml",graph),("normalize_data.sml",normal),("identifier_data.sml",ident),("security_data.sml",security)]
        val ()=List.app (fn (name,data) => T.atomic (output ^ "/lib/unicode/" ^ name) data) outputs
        val ()=List.app (fn name => copy (directory ^ "/" ^ text name) (output ^ "/tests/lib/unicode/" ^ text name)) (array (field "TEST_DATA" cfg))
        val labels=["zero ","control ","wide ","break ","pictographic ","conjunct "]
        val counts=wcounts @ gcounts
        val summary=String.concatWith ", " (ListPair.map (fn (label,n) => label ^ Int.toString n ^ (if label="zero " orelse label="control " orelse label="wide " then " ranges" else "")) (labels,counts))
        (* Keep the original compact summary: only the width counts say ranges. *)
        val summary="zero " ^ Int.toString (List.nth (counts,0)) ^ ", control " ^ Int.toString (List.nth (counts,1)) ^ ", wide " ^ Int.toString (List.nth (counts,2)) ^ " ranges; break " ^ Int.toString (List.nth (counts,3)) ^ ", pictographic " ^ Int.toString (List.nth (counts,4)) ^ ", conjunct " ^ Int.toString (List.nth (counts,5))
    in say (summary ^ "\n" ^ normalSummary ^ "\n" ^ identSummary ^ "\n" ^ securitySummary ^ "\n");0 end
end
