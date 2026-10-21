(* Specification transcriptions, dependency ordering and token agreement.
   The compiler supplies lexical/dependency observations; SML owns policy. *)
structure GenerateSignatures =
struct
  open MeasureCommon
  structure T=GenerateText
  val start="(* ---- the signatures of the specification (scripts/gen-basis-sigs.sh) *)"
  val finish="(* ---- end of the signatures"
  fun declarations prefix source =List.mapPartial (fn line => if String.isPrefix ("signature " ^ prefix) line then
        let val rest=String.extract (line,10+size prefix,NONE)
            val name=Substring.string (Substring.takel (fn c => Char.isUpper c orelse Char.isDigit c orelse c = #"_") (Substring.full rest))
        in SOME name end else NONE) (lines source)
  fun rename prefix source=T.substitute (prefix ^ "[A-Z0-9_]+") (fn s => String.extract (s,size prefix,NONE)) source
  fun baseBuild source =
    let val skip=ref false
        fun row line=if line=start then (skip:=true;[line,"@BLOCK@"]) else
             (if !skip andalso String.isPrefix finish line then skip:=false else ();if !skip then [] else [line])
        val input=String.fields (fn c => c = #"\n") source val input=if List.last input="" then List.take (input,length input-1) else input
    in List.concat (List.map row input) end
  fun buildText base block =
    let val had=List.exists (fn row => row="@BLOCK@") base val done=ref false
        fun row line=if line="@BLOCK@" then (done:=true;block) else if not (!done) andalso not had andalso String.isPrefix "annotate \"final\"" line then
               (done:=true;[start] @ block @ [finish ^ " *)",line]) else [line]
        val rows=List.concat (List.map row base)
    in String.concat (List.map (fn line => line ^ "\n") (rows @ (if !done then [] else [start] @ block @ [finish ^ " *)"]))) end
  fun main args =
    let val (check,library)=case args of [] => (false,"lib") | ["--check"] => (true,"lib") | [lib] => (false,lib) | ["--check",lib] => (true,lib) | _ => raise Usage "basis-signatures [--check] [LIBDIR]"
        val library=fromRoot library val basis=library ^ "/basis" val manifest=basis ^ "/MANIFEST" val build=basis ^ "/library.build"
        val ()=need (exists manifest,"no " ^ manifest ^ " (make manifests)")
        val tmp=T.privateDirectory (fromRoot "tests/out/generate") "signatures"
        val ()=mkdirs (tmp ^ "/out")
        val rune=tool "RUNE" (fromRoot "bin/rune") val counter=ref 0
        fun observe args=let val ()=counter:= !counter+1 in successful (execute root (tmp ^ "/compiler-" ^ Int.toString (!counter)) (rune @ args)) end
        val base=baseBuild (read build)
        val files=List.filter (String.isSuffix ".sml") (GenerateMLB.tokenize (String.concatWith "\n" base))
        val provided=List.concat (List.mapPartial (fn line => case List.map trim (fields #"|" line) of file::_::_::names::_ => if List.exists (fn name => name=file) files then SOME (String.tokens Char.isSpace names) else NONE | _ => NONE) (T.dataLines manifest))
        val own=GenerateText.distinct (List.concat (List.map (fn file => declarations "" (read (basis ^ "/" ^ file))) files))
        val transcriptions=List.filter (not o String.isSuffix "_IMP.sml") (glob (fromRoot "tests/basis/spec-sigs",".sml"))
        val sigs=List.concat (List.map (fn file => List.map (fn name => (name,file)) (List.filter (fn name => not (List.exists (fn old => old=name) own)) (declarations "SPEC_" (read file)))) transcriptions)
        val generated=List.map #1 sigs val all=GenerateText.distinct (provided @ generated)
        fun generatedName name="sig_" ^ String.map Char.toLower name ^ ".sml"
        val edges=List.concat (List.map (fn (name,file) =>
              let val output=tmp ^ "/out/" ^ generatedName name val ()=write (output,rename "SPEC_" (read file))
                  val deps=List.filter (fn dep => dep<>name andalso List.exists (fn a => a=dep) all) (lines (observe ["--deps-uses",output]))
              in (name,name)::List.map (fn dep => (dep,name)) (List.filter (fn dep => List.exists (fn a => a=dep) generated) deps) end) sigs)
        val block=["annotate \"demand\" in"] @ List.map (fn name => "  " ^ generatedName name) (GenerateTopo.order edges) @ ["end"]
        val desired=buildText base block
        val specs=List.map (fn file => let val scr=fromRoot ("tests/basis/spec-sigs/scr/" ^ OS.Path.file file) val source=if exists scr then scr else file
                           val dest=tmp ^ "/spec_" ^ OS.Path.file file val ()=write (dest,rename "SPEC_" (rename "SCR_" (read source))) in dest end) transcriptions
        fun tokens files =
          let val raw=observe ("--dump-tokens"::files)
              val raw=List.mapPartial (fn line => Option.map #2 (T.splitAt " " line)) (lines raw)
              val depth=ref 0 val signatureName=ref "" val want=ref false val result=ref [] : (string*string) list ref
              fun token word =
                if !depth=0 andalso List.exists (fn w => w=word) ["signature","structure","functor"] then (signatureName:="";if word="signature" then want:=true else ())
                else if word="<eof>" then signatureName:=""
                else if !want then (signatureName:=word;want:=false)
                else (if List.exists (fn w => w=word) ["sig","struct","let","local"] then depth:= !depth+1 else if word="end" then depth:= !depth-1 else ();
                      if !signatureName="" then () else result:=(!signatureName,if !signatureName="PRIM_IO" andalso word="RuneIODesc.iodesc" then "OS.IO.iodesc" else word):: !result)
          in List.app token raw;List.rev (!result) end
        val specTokens=if check then tokens specs else []
        val actual=if check then tokens (List.filter (fn f => List.exists (String.isPrefix "signature ") (lines (read f))) (glob (basis,".sml"))) else []
        val names=sort (T.distinct (List.map #1 specTokens))
        val bad=ref false
        fun failure text=(bad:=true;say ("gen-basis-sigs: " ^ text ^ "\n"))
        fun compare name =
          let val expected=List.filter (fn (s,_) => s=name) specTokens val found=List.filter (fn (s,_) => s=name) actual
          in if null found then failure ("signature " ^ name ^ " is transcribed in tests/basis/spec-sigs and missing from " ^ basis ^ " (run rune-generate basis-signatures for a copy to start from)")
             else if expected<>found then failure ("signature " ^ name ^ " of " ^ basis ^ " differs from its transcription") else () end
        val ()=if not check then () else
           (if desired=read build then () else failure ("the block of " ^ build ^ " is not up to date (run rune-generate basis-signatures)");List.app compare names;
            List.app (fn file => let val sigNames=declarations "" (read file) val sigName=case sigNames of first::_ => first | [] => ""
               in if exists (tmp ^ "/out/" ^ OS.Path.file file) orelse List.exists (fn file => List.exists (fn name => name=sigName) (declarations "SPEC_" (read file))) transcriptions then () else failure (file ^ " has no transcription any more") end) (List.filter (String.isPrefix "sig_" o OS.Path.file) (glob (basis,".sml"))))
        val ()=if check then if !bad then () else say ("gen-basis-sigs: OK (" ^ Int.toString (length names) ^ " signatures have the tokens of their transcriptions)\n") else
             let val count=ref 0
                 val ()=List.app (fn (name,_) => let val dest=basis ^ "/" ^ generatedName name in if exists dest then () else
                       (copy (tmp ^ "/out/" ^ generatedName name) dest;count:= !count+1;say ("gen-basis-sigs: wrote " ^ dest ^ ", a copy of its transcription\n")) end) sigs
                 val ()=T.atomic build desired val _=observe ["--basis-index",basis]
             in say ("gen-basis-sigs: " ^ Int.toString (!count) ^ " new signature files in " ^ basis ^ "; the block of " ^ build ^ " is written, and " ^ manifest ^ "\n") end
    in rmTree tmp;if !bad then 1 else 0 end
end
