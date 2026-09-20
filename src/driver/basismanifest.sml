(* The basis library's MANIFEST and the choice of the files a program loads:
   shared by the compiler driver and runedoc. *)
structure BasisManifest =
struct
  exception Usage of string

  (* ---- the basis library: lib/basis/MANIFEST ----
     One file per line, in load order:
       file | always or demand | host | provides | requires
     provides: the structures, signatures and functors the file declares;
     requires: those of other files that it names. (host is for the
     cross-check of tests/basis.) A program is compiled after the always
     files, the files that provide a name it mentions, and what those require:
     the scan below looks at identifiers only, so it may load a file the
     program does not need, never miss one it does. A name can have several
     files, as IO and OS do (the structure and the signature of the
     specification); naming it loads them all. *)
  datatype when = Always | Demand | Final
  (* requires is read from the text when it is asked for: most programs need
     it of few files *)
  type entry = {file : string, when : when, provides : string list, requires : unit -> string list}

  fun trim (s : string) : string =
    let
      val n = String.size s
      fun left i = if i < n andalso Char.isSpace (String.sub (s, i)) then left (i + 1) else i
      fun right j = if j > 0 andalso Char.isSpace (String.sub (s, j - 1)) then right (j - 1) else j
      val i = left 0
      val j = right n
    in if i >= j then "" else String.substring (s, i, j - i) end

  (* The MANIFEST is read for every program, so it is scanned in one pass
     over its text, a line at a time, with the bars and the words of a line
     found by index rather than by splitting it into strings first. *)
  fun readManifest (dir : string) : entry list =
    let
      val manifest = dir ^ "/MANIFEST"
      val ins = TextIO.openIn manifest
                handle IO.Io _ => raise Usage ("cannot read basis manifest " ^ manifest ^ " (use --lib or --no-prelude)")
      val text = TextIO.inputAll ins before TextIO.closeIn ins
      val n = String.size text
      fun at k = String.sub (text, k)
      fun blank c = c = #" " orelse c = #"\t" orelse c = #"\r"
      (* the words of text[i, j) *)
      fun words (i, j) =
        let
          fun skip k = if k < j andalso blank (at k) then skip (k + 1) else k
          fun stop k = if k < j andalso not (blank (at k)) then stop (k + 1) else k
          fun go (k, acc) =
            let val a = skip k
            in if a >= j then List.rev acc else let val e = stop a in go (e, String.substring (text, a, e - a) :: acc) end end
        in go (i, []) end
      fun bad (i, e) = raise Usage ("malformed line in " ^ manifest ^ ": " ^ String.substring (text, i, e - i))
      (* the one word of text[i, j), or NONE *)
      fun one (i, j) = case words (i, j) of [w] => SOME w | _ => NONE
      (* a line text[i, e) of five fields *)
      fun entry (i, e) =
        let
          fun bars (k, acc) = if k >= e then List.rev acc else bars (k + 1, if at k = #"|" then k :: acc else acc)
        in
          case bars (i, []) of
            [b1, b2, b3, b4] =>
              (case (one (i, b1), one (b1 + 1, b2)) of
                 (SOME file, SOME mode) =>
                   {file = file,
                    when = (case mode of "always" => Always | "demand" => Demand | "final" => Final | _ => bad (i, e)),
                    provides = words (b3 + 1, b4), requires = fn () => words (b4 + 1, e)}
               | _ => bad (i, e))
          | _ => bad (i, e)
        end
      fun go (i, acc) =
        if i >= n then List.rev acc
        else
          let
            fun eol k = if k < n andalso at k <> #"\n" then eol (k + 1) else k
            val e = eol i
            fun first k = if k < e andalso blank (at k) then first (k + 1) else k
            val f = first i
          in
            if f >= e orelse at f = #"#" then go (e + 1, acc) else go (e + 1, entry (i, e) :: acc)
          end
    in go (0, []) end

  type names = unit StringMap.map

  (* The identifiers of a token stream, and the heads of its long identifiers. *)
  fun namesOf (toks : Lexer.item vector, acc : names) : names =
    Vector.foldl (fn ((Token.ID s, _), acc) => StringMap.insert (acc, s, ())
                   | ((Token.LONGID (s :: _, _), _), acc) => StringMap.insert (acc, s, ())
                   | (_, acc) => acc) acc toks

  (* name -> the files that provide it, in MANIFEST order *)
  fun providers (entries : entry list) : string list StringMap.map =
    List.foldl (fn (e : entry, m) =>
                   List.foldl (fn (n, m) =>
                                  StringMap.insert (m, n, (case StringMap.find (m, n) of
                                                             SOME fs => fs @ [#file e]
                                                           | NONE => [#file e])))
                              m (#provides e))
               StringMap.empty entries

  (* The entries to load for a program that mentions the given names, in
     MANIFEST order. *)
  fun select (entries : entry list, mentioned : names) : entry list =
    let
      (* The files that provide a name: a scan of the entries, compared with
         the primitive =, for the few names the chosen files require (a map of
         every name would cost more to build than a program needs). *)
      fun providersOf n = List.filter (fn e : entry => List.exists (fn p => p = n) (#provides e)) entries
      fun required (e : entry) = List.filter (fn n => not (String.isPrefix "-" n)) (#requires e ())
      fun add (e : entry, chosen : names) : names =
        if StringMap.member (chosen, #file e) then chosen
        else
          List.foldl (fn (n, chosen) =>
                         case providersOf n of
                           [] => raise Usage ("basis manifest: " ^ #file e ^ " requires " ^ n ^
                                                      ", which no file provides")
                         | es => List.foldl add chosen es)
                     (StringMap.insert (chosen, #file e, ()))
                     (required e)
      val wanted = fn e : entry => #when e = Always orelse List.exists (fn n => StringMap.member (mentioned, n)) (#provides e)
      val chosen = List.foldl (fn (e, chosen) => if wanted e then add (e, chosen) else chosen) StringMap.empty entries
      (* A file compiled after the program joins it only when what it needs is
         there anyway: a program that never mentions OS has nothing to do when
         it ends. *)
      val chosen =
        List.foldl (fn (e : entry, chosen) =>
                       if #when e = Final
                          andalso List.all (fn n => List.exists (fn e' : entry => StringMap.member (chosen, #file e'))
                                                                (providersOf n))
                                           (required e)
                       then add (e, chosen) else chosen)
                   chosen entries
    in List.filter (fn e : entry => StringMap.member (chosen, #file e)) entries end
end
