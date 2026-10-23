(* Development frontend driver. Clang is an independent oracle invoked by
   tests, never an implementation dependency of these operations. *)
structure CFrontendMain =
struct
  fun read path = #text (CFiles.read path)
  fun write (path, text) = let val out = TextIO.openOut path
    in TextIO.output (out, text); TextIO.closeOut out end
  fun field name value = case Json.member (name, value) of SOME v => v | NONE => raise Fail ("missing " ^ name)
  fun string (Json.String s) = s | string _ = raise Fail "expected JSON string"
  fun array (Json.Array vs) = vs | array _ = raise Fail "expected JSON array"
  fun profile path = List.map (fn item => case array item of [name, value] => (string name, string value)
    | _ => raise Fail "expected predefined name/value pair") (array (field "predefined" (Json.decode (read path))))
  (* Clang consumes diagnostic/linker pragmas while Rune retains them for
     reporting. Compare declarations and all packing directives exactly. *)
  fun comparable tokens =
    let fun strip [] = []
          | strip ((hash : CLex.token) :: pragma :: kind :: rest) =
            if #text hash = "#" andalso #text pragma = "pragma" then
              let fun line ([], acc) = (rev acc, [])
                    | line (t :: ts, acc) = if #kind t = CLex.Newline then (rev acc, ts) else line (ts, t :: acc)
                  val (body, after) = line (kind :: rest, [])
              in (if #text kind = "pack" then hash :: pragma :: body else []) @ strip after end
            else hash :: strip (pragma :: kind :: rest)
          | strip (t :: rest) = t :: strip rest
    in List.filter (fn (t : CLex.token) => #kind t <> CLex.Newline) (strip tokens) end
  fun compare (left, right) =
    let fun tokens path = comparable (CLex.scan {file = path, text = read path})
        fun preview (ts : CLex.token list) = String.concatWith " "
          (List.map #text (List.take (ts, Int.min (24, length ts))))
        fun go ([], [], n) = print ("PASS C preprocessing: " ^ Int.toString n ^ " identical tokens\n")
          | go (a :: xs, b :: ys, n) = if #text a = #text b then go (xs, ys, n + 1)
            else raise Fail ("token " ^ Int.toString n ^ ":\n" ^ preview (a :: xs) ^ "\nversus\n" ^ preview (b :: ys))
          | go _ = raise Fail "preprocessing token counts differ"
    in go (tokens left, tokens right, 0) end
  fun headers profilePath output source roots =
    let val preprocessed = CPreprocess.run {source = CFiles.read source, predefined = profile profilePath,
          resolve = CFiles.resolver roots, width = 64, maxDepth = 256, maxExpansions = 10000000}
        val declarations = CParse.translationUnit {tokens = #tokens preprocessed, predefinedTypes = []}
        val () = write (output, CLex.spelling (#tokens preprocessed))
        val names = List.mapPartial (fn CParse.Declaration {name, ...} => name | _ => NONE) (#declarations declarations)
        val () = write (output ^ ".names", String.concatWith "\n" names ^ "\n")
        val () = write (output ^ ".deps", String.concatWith "\n" (#dependencies preprocessed) ^ "\n")
    in print (Int.toString (length (#dependencies preprocessed)) ^ " original files, " ^
              Int.toString (length (#declarations declarations)) ^ " declarations\n") end
  fun main ("headers" :: target :: output :: source :: roots) = headers target output source roots
    | main ["parse", source] =
        let val result = CParse.translationUnit {tokens = CLex.scan {file = source, text = read source}, predefinedTypes = []}
        in print (Int.toString (length (#declarations result)) ^ " declarations\n") end
    | main ["compare", left, right] = compare (left, right)
    | main ["predefines", profilePath, output] = write (output, String.concat
        (List.map (fn (name, value) => "#define " ^ name ^ " " ^ value ^ "\n")
          (profile profilePath)))
    | main _ = raise Fail "expected headers PROFILE OUTPUT SOURCE INCLUDE..., parse SOURCE, compare LEFT RIGHT, or predefines PROFILE OUTPUT"
  fun diagnostic ({file, line, column} : CLex.location, message) =
    file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column ^ ": " ^ message
  fun failure e = case e of CLex.Error p => diagnostic p | CConst.Error p => diagnostic p
    | CPreprocess.Error p => diagnostic p | CParse.Error p => diagnostic p | _ => General.exnMessage e
end
val () = CFrontendMain.main (CommandLine.arguments ()) handle e =>
  (TextIO.output (TextIO.stdErr, "C frontend: " ^ CFrontendMain.failure e ^ "\n"); OS.Process.exit OS.Process.failure)
