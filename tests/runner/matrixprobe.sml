(* Native structure/signature probes and compiler error locations shared by
   host laws and matrix section recovery. A failed probe is never evidence
   that every requested structure exists. *)
structure MatrixProbe =
struct
  open Sh
  exception Failed of string
  fun unique xs = List.foldl (fn (x, acc) => if List.exists (fn y => x = y) acc then acc else acc @ [x]) [] xs
  fun difference (xs, ys) = List.filter (fn x => not (List.exists (fn y => x = y) ys)) xs
  fun errorLines host messages source =
    let
      val base = OS.Path.file source
      val marker = base ^ (if host = "mlton" then " " else if host = "mlkit" then ", line " else ":")
      fun one line =
        let
          fun search text acc =
            let val (pre, rest) = Substring.position marker (Substring.full text)
            in if Substring.isEmpty rest then acc else
              let val prefix = Substring.string pre
                  val tail = Substring.triml (size marker) rest
                  val digits = Substring.takel Char.isDigit tail
                  val after = Substring.triml (Substring.size digits) tail
                  val boundary = size prefix = 0 orelse not (Char.isAlphaNum (String.sub (prefix, size prefix - 1))
                                                         orelse Char.contains "_.-" (String.sub (prefix, size prefix - 1)))
                  val stop = if host = "mlkit" then String.isPrefix ", column" (Substring.string after)
                             else if host = "polyml" then String.isPrefix ": error" (Substring.string after)
                             else String.isPrefix "." (Substring.string after)
                  val n = if boundary andalso stop then Int.fromString (Substring.string digits) else NONE
                  val rest = Substring.string tail
              in search rest (case n of SOME n => n :: acc | NONE => acc) end end
        in if String.isPrefix "smlnj" host andalso not (String.isSubstring " Error:" line) then [] else search line [] end
    in unique (List.concat (List.map one (lines messages))) end
  fun staticError host text =
    List.exists (fn marker => String.isSubstring marker text)
      (if host = "polyml" then [": error:", "Static Errors", "Exception-"]
       else if host = "mlkit" then ["Error:", "error:", "Compilation failed", "Stopping compilation of MLB-file due to error"]
       else ["Error:", "uncaught exception"])
  fun sessionError host sources text =
    let fun located line = List.exists (fn source => not (null (errorLines host line source))) sources
    in if String.isPrefix "smlnj" host then
         List.exists (fn line => String.isSubstring " Error:" line andalso located line) (lines text)
       else if host = "polyml" then
         List.exists (fn line => (String.isSubstring ": error:" line andalso located line)
                      orelse Hosts.trim line = "Static Errors"
                      orelse String.isPrefix "Exception- Static Errors" (Hosts.trim line)) (lines text)
       else staticError host text end
  fun probe {host = h : Hosts.host, names, directory, signatureProbe} =
    let
      val names = sort names
      fun validPart part = size part > 0 andalso (Char.isAlpha (String.sub (part, 0)) orelse String.sub (part, 0) = #"_")
            andalso CharVector.all (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #"'") part
      val () = if List.all (fn name => List.all validPart (String.fields (fn c => c = #".") name)) names then ()
               else raise Failed "invalid capability name"
      val () = mkdirs directory
      val source = directory ^ "/probe.sml"
      val declaration = if signatureProbe then "signature" else "structure"
      fun fresh i =
        let val name = "MigrationProbeSanity" ^ Int.toString i
        in if List.exists (fn n => hd (String.fields (fn c => c = #".") n) = name) names then fresh (i + 1) else name end
      val () = write (source, "structure " ^ fresh 0 ^ " = Int\n" ^ String.concat (List.map (fn (i, name) => declaration ^ " P" ^ Int.toString i ^ " = " ^ name ^ "\n")
                         (ListPair.zip (List.tabulate (length names, fn i => i), names))))
      val () = write (directory ^ "/probe.mlb", "$(SML_LIB)/basis/basis.mlb\nprobe.sml\n")
      val () = write (directory ^ "/probe.use", "use \"probe.sml\";\n")
      val host = #name h
      val changes = if host = "mlkit" then setEnv ("SML_LIB", #library h) else fn e => e
      val command = if host = "mlton" then [#program h, "-stop", "tc", "probe.mlb"]
                    else if host = "mlkit" then [#program h, "-o", "probe", "probe.mlb"]
                    else if host = "polyml" then [#program h, "-q", "--maxheap", "2048"]
                    else [#program h, "probe.sml"]
      val input = if host = "polyml" then directory ^ "/probe.use" else ""
      val limits = {addressSpace = SOME (if host = "polyml" then 4294967296 else 8589934592),
                    cpuTime = SOME 600, fileSize = SOME (64 * 1024 * 1024), core = SOME 0}
      val status = Children.exec limits changes
         {cmd = command, dir = SOME directory, stdin = input, stdout = directory ^ "/probe.out",
          stderr = directory ^ "/probe.err", timeout = 600}
      val output = read (directory ^ "/probe.out") ^ read (directory ^ "/probe.err")
      val errors = errorLines host output source
      val () = if List.exists (fn n => n = 1) errors then raise Failed (host ^ ": failed the mandatory Int capability sanity check") else ()
      val missing = List.mapPartial (fn i => if i > 1 andalso i <= length names + 1 then SOME (List.nth (names, i - 2)) else NONE) errors
      (* MLKit reports a normal static error as process status 255, while
         its diagnostic says code 1. Accept it only with located errors. *)
      val normal = status = 0 orelse status = 1 orelse (host = "mlkit" andalso status = 255)
      val () = if normal andalso (not (null missing) orelse (status = 0 andalso not (staticError host output)))
               then () else raise Failed (host ^ ": capability probe failed (exit " ^ Int.toString status ^ "): " ^ firstNonEmpty (directory ^ "/probe.err"))
    in unique missing end
  fun missingOn {host, names, directory} =
    let
      fun loop ([], missing) = missing
        | loop (rest, missing) =
            let val absent = probe {host = host, names = rest, directory = directory, signatureProbe = false}
            in if null absent then missing else loop (difference (rest, absent), unique (missing @ absent)) end
      val missing = loop (unique names, [])
      fun signatureName name = not (String.isSubstring "." name) andalso size name > 0
          andalso Char.isUpper (String.sub (name, 0)) andalso CharVector.all (fn c => Char.isUpper c orelse Char.isDigit c orelse c = #"_") name
      val signatures = List.filter signatureName missing
      val absent = if null signatures then [] else probe {host = host, names = signatures, directory = directory, signatureProbe = true}
    in difference (missing, difference (signatures, absent)) end
end
