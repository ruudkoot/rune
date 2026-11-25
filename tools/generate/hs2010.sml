(* Haskell 2010's programs of the rows 2010 renames (the haskell2010 roadmap's
   M1, The generator): each program of tests/hs/{lang,accept,errors} that
   imports a module of Haskell 98's library is written again for
   tests/hs2010, its imports rewritten by the import map and its rows by the
   2010 table, so that a 98 row under a renamed module (812 of the table's
   905 changed rows, List under Data.List and the like) gets 98's program as
   its 2010 one.

   The import map is the 2010 table's: a row whose `how` says `rename A ->
   B` maps the 98 module A to the 2010 module B, and a module that two such
   notes map, IO and System, goes to both (System.IO and System.IO.Error;
   System.Environment and System.Exit). A module of 98's library that no
   note renames is 2010's under its own name where the table's rows say it
   exports something (Numeric), and is dropped otherwise (CPUTime,
   Directory, Locale, Random, Time). An import of a renamed module A keeps
   A's names: `import A (xs)` becomes `import B as A (xs)`, its qualifier
   and its `as` kept; one of a split module becomes an import of each 2010
   module, its list (or its hiding list) parted by what each exports by the
   table's `module M exports x` rows, side by side on the declaration's
   line, so that no line of the program moves.

   A program's rows are its name's id and those of its first line (`--
   rows:`), as tests/runner/hsconformance.sml reads them: each becomes the
   2010 row of the same id where 2010 keeps it (`same`), else the changed
   row that comes from it; a reading it pins stays where a row it now names
   carries it, and `deviation` goes, since a deviation is its own table's.
   Its name is its name's row's 2010 id and the rest of its name; its
   siblings are copied with its path, tests/hs/DIR/NAME, made the path it
   would have, tests/hs2010/DIR/NEW. A program is left out, with why, where
   a module it imports is dropped, a row it names has no 2010 row, or a name
   it imports of a split module none of its 2010 modules exports.

   `hs2010-programs --out DIR [--root ROOT]` writes them under DIR/lang,
   DIR/accept and DIR/errors, with DIR/generated.tsv (each program written:
   its directory, the 98 program, the 2010 one, its rows, what it dropped)
   and DIR/skipped.tsv (each left out, and why). It reads ROOT's tests/hs
   and tests/hs2010/conformance.tsv (this tree's where not given). *)
structure GenerateHs2010 =
struct
  exception Skip of string

  fun tabs line = String.fields (fn c => c = #"\t") line
  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))
  fun member x xs = List.exists (fn y => y = x) xs
  fun dedup xs = List.foldl (fn (x, acc) => if member x acc then acc else acc @ [x]) [] xs

  (* ---- the 2010 table *)
  type row = {id : string, delta : string, map98 : string list, how : string, statement : string, reading : string list}
  fun table root : row list =
    case Sh.lines (Sh.read (root ^ "/tests/hs2010/conformance.tsv")) of
      [] => raise MeasureCommon.Failed ("no " ^ root ^ "/tests/hs2010/conformance.tsv")
    | head :: rest =>
        let
          val hs = tabs head
          fun col (fs, name) =
            let fun go (h :: hs, f :: fs) = if h = name then f else go (hs, fs) | go _ = "" in go (hs, fs) end
        in
          List.map (fn l => let val fs = tabs l
                            in {id = col (fs, "id"), delta = col (fs, "delta"), map98 = String.tokens Char.isSpace (col (fs, "map98")),
                                how = col (fs, "how"), statement = col (fs, "statement"),
                                reading = String.tokens Char.isSpace (col (fs, "reading"))} end) rest
        end

  (* the modules of Haskell 98's library, the Report's chapters 12 to 27 *)
  val library98 = ["Array", "Char", "Complex", "CPUTime", "Directory", "IO", "Ix", "List", "Locale", "Maybe", "Monad", "Numeric",
                   "Random", "Ratio", "System", "Time"]

  (* the words after `prefix` in `text`, up to a space, a semicolon or the end *)
  fun after (prefix, text) =
    let
      val (_, rest) = Substring.position prefix (Substring.full text)
    in
      if Substring.isEmpty rest then NONE
      else SOME (Substring.string (Substring.takel (fn c => not (Char.isSpace c) andalso c <> #";" andalso c <> #",")
                                                   (Substring.triml (size prefix) rest)))
    end

  (* the import map: each 98 module to its 2010 modules, by the notes `rename
     A -> B`; a module no note renames is kept where 2010 exports from it,
     else dropped (no modules) *)
  fun exportsOf (rows : row list) m =
    List.mapPartial (fn (r : row) =>
                       if #delta r = "removed-in-2010" then NONE
                       else case String.tokens Char.isSpace (#statement r) of
                              "module" :: m' :: "exports" :: item :: _ =>
                                if m' = m then SOME (hd (String.fields (fn c => c = #"(") item)) else NONE
                            | _ => NONE) rows
  (* the rename a row's note gives: `rename A -> B` *)
  fun renameOf (r : row) =
    let fun go ("rename" :: a :: "->" :: b :: _) = SOME (a, String.translate (fn #";" => "" | #"," => "" | c => str c) b)
          | go (_ :: rest) = go rest
          | go [] = NONE
    in go (String.tokens Char.isSpace (#how r)) end
  fun importMap (rows : row list) =
    let
      val pairs = dedup (List.mapPartial renameOf rows)
    in
      List.map (fn m => case List.mapPartial (fn (a, b) => if a = m then SOME b else NONE) pairs of
                          [] => (m, if null (exportsOf rows m) then [] else [m])
                        | bs => (m, bs)) library98
    end

  (* ---- 98's rows to 2010's: the row of the same id where 2010 keeps it,
     else the renamed row that comes from it; a row 2010 removes, or changes
     beyond a rename, has no program written so *)
  fun renamedFrom (rows : row list) id =
    List.find (fn (r : row) => #delta r = "changed" andalso member id (#map98 r) andalso isSome (renameOf r)) rows
  fun mapId (rows : row list) id =
    case List.find (fn (r : row) => #id r = id) rows of
      SOME r => if #delta r = "same" then id
                else raise Skip ("it names " ^ id ^ ", which Haskell 2010 removes")
    | NONE =>
        case renamedFrom rows id of
          SOME r => #id r
        | NONE =>
            case List.find (fn (r : row) => member id (#map98 r)) rows of
              SOME r => raise Skip ("it names " ^ id ^ ", which Haskell 2010 changes beyond a rename (" ^ #id r
                                    ^ "): its 2010 program is written by hand")
            | NONE => raise Skip ("it names " ^ id ^ ", which has no row in Haskell 2010's table")

  (* ---- a program's first line, as hsconformance.sml reads it *)
  fun isReading w = size w > 1 andalso (String.sub (w, 0) = #"R" orelse String.sub (w, 0) = #"N")
                    andalso CharVector.all Char.isDigit (String.extract (w, 1, NONE))
  fun firstLineOf text = hd (String.fields (fn c => c = #"\n" orelse c = #"\r" orelse c = #"\f") text)
  fun rowsWords line =
    let val l = if String.isPrefix "> " line then String.extract (line, 2, NONE) else line
    in case String.tokens Char.isSpace l of "--" :: "rows:" :: ws => SOME ws | _ => NONE end

  (* ---- an import declaration *)
  (* the items of a parenthesised list, by its top-level commas *)
  fun items text =
    let
      fun go ([], depth, cur, acc) = List.rev (if trim (implode (List.rev cur)) = "" then acc else trim (implode (List.rev cur)) :: acc)
        | go (#"(" :: cs, depth, cur, acc) = go (cs, depth + 1, #"(" :: cur, acc)
        | go (#")" :: cs, depth, cur, acc) = go (cs, depth - 1, #")" :: cur, acc)
        | go (#"," :: cs, 0, cur, acc) = go (cs, 0, [], trim (implode (List.rev cur)) :: acc)
        | go (c :: cs, depth, cur, acc) = go (cs, depth, c :: cur, acc)
    in go (explode text, 0, [], []) end
  (* the name an item imports: an operator in parentheses, or the name
     before its subordinates *)
  fun itemName item =
    if String.isPrefix "(" item then trim (String.substring (item, 1, Int.max (0, size item - 2)))
    else trim (hd (String.fields (fn c => c = #"(" orelse Char.isSpace c) item))

  type decl = {qualified : bool, module : string, alias : string option, hiding : bool, list : string list option, rest : string}
  (* an import declaration's text, one line: its parts, or NONE where it is
     no plain import (a comment, a line that only begins so) *)
  fun parse text : decl option =
    let
      val ws = Substring.full text
      fun word s = Substring.splitl (fn c => not (Char.isSpace c) andalso c <> #"(" andalso c <> #";") (Substring.dropl Char.isSpace s)
      val (kw, s) = word ws
      val (q, s) = let val (w, s') = word s in if Substring.string w = "qualified" then (true, s') else (false, s) end
      val (m, s) = word s
      val (alias, s) = let val (w, s') = word s
                       in if Substring.string w = "as" then let val (a, s'') = word s' in (SOME (Substring.string a), s'') end
                          else (NONE, s) end
      val (hiding, s) = let val (w, s') = word s in if Substring.string w = "hiding" then (true, s') else (false, s) end
      val s = Substring.dropl Char.isSpace s
      fun close (cs, depth, k) =
        case cs of
          [] => NONE
        | #"(" :: rest => close (rest, depth + 1, k + 1)
        | #")" :: rest => if depth = 1 then SOME (k + 1) else close (rest, depth - 1, k + 1)
        | _ :: rest => close (rest, depth, k + 1)
    in
      if Substring.string kw <> "import" orelse Substring.isEmpty m then NONE
      else if Substring.isPrefix "(" s then
        case close (explode (Substring.string s), 0, 0) of
          SOME k => let val all = Substring.string s
                    in SOME {qualified = q, module = Substring.string m, alias = alias, hiding = hiding,
                             list = SOME (items (String.substring (all, 1, k - 2))), rest = String.extract (all, k, NONE)} end
        | NONE => NONE
      else SOME {qualified = q, module = Substring.string m, alias = alias, hiding = hiding, list = NONE, rest = Substring.string s}
    end

  fun show ({qualified, module, alias, hiding, list, rest} : decl) =
    "import " ^ (if qualified then "qualified " else "") ^ module ^ (case alias of SOME a => " as " ^ a | NONE => "")
    ^ (if hiding then " hiding" else "")
    ^ (case list of SOME xs => " (" ^ String.concatWith ", " xs ^ ")" | NONE => "")
    ^ (if trim rest = "" then "" else " " ^ trim rest)

  (* a declaration of a 98 module rewritten by the map: its 2010 imports,
     side by side; NONE where its module is no 98 module's *)
  fun rewrite (imap, exportsOf) (d : decl) : string option =
    case List.find (fn (m, _) => m = #module d) imap of
      NONE => NONE
    | SOME (_, []) => raise Skip ("it imports " ^ #module d ^ ", which Haskell 2010's library drops")
    | SOME (m, [b]) => SOME (show {qualified = #qualified d, module = b, alias = SOME (getOpt (#alias d, m)), hiding = #hiding d,
                                   list = #list d, rest = #rest d})
    | SOME (m, bs) =>
        let
          val alias = SOME (getOpt (#alias d, m))
          fun one (b, list) = show {qualified = #qualified d, module = b, alias = alias, hiding = #hiding d, list = list, rest = ""}
          val decls =
            case (#list d, #hiding d) of
              (NONE, _) => List.map (fn b => one (b, NONE)) bs
            | (SOME [], false) => [one (hd bs, SOME [])]
            | (SOME xs, false) =>
                let
                  val () = List.app (fn x => if List.exists (fn b => member (itemName x) (exportsOf b)) bs then ()
                                             else raise Skip ("it imports " ^ itemName x ^ " of " ^ m ^ ", which no module of "
                                                              ^ String.concatWith " or " bs ^ " exports")) xs
                in
                  List.mapPartial (fn b => case List.filter (fn x => member (itemName x) (exportsOf b)) xs of
                                             [] => NONE
                                           | ys => SOME (one (b, SOME ys))) bs
                end
            | (SOME xs, true) =>
                List.map (fn b => case List.filter (fn x => member (itemName x) (exportsOf b)) xs of
                                    [] => show {qualified = #qualified d, module = b, alias = alias, hiding = false, list = NONE,
                                                rest = ""}
                                  | ys => show {qualified = #qualified d, module = b, alias = alias, hiding = true, list = SOME ys,
                                                rest = ""}) bs
        in SOME (String.concatWith "; " decls ^ (if trim (#rest d) = "" then "" else " " ^ trim (#rest d))) end

  (* a module's text with each import of a 98 module rewritten in place: a
     declaration over several lines becomes one, the others left empty, so
     that no later line moves; a literate module's code lines keep their
     bird tracks *)
  fun rewriteModule (imap, exportsOf) (text, lhs) =
    let
      val ls = String.fields (fn c => c = #"\n") text
      fun code l = if lhs then (if String.isPrefix "> " l then SOME (String.extract (l, 2, NONE))
                                else if l = ">" then SOME "" else NONE)
                   else SOME l
      fun openParens s =
        (* the parentheses a line leaves open, its comment after -- aside *)
        let val (pre, _) = Substring.position "--" (Substring.full s)
        in CharVector.foldl (fn (#"(", n) => n + 1 | (#")", n) => n - 1 | (_, n) => n) 0 (Substring.string pre) end
      fun go ([], acc) = List.rev acc
        | go (l :: rest, acc) =
            case code l of
              NONE => go (rest, l :: acc)
            | SOME c =>
                if not (String.isPrefix "import" (trim c) andalso size (trim c) > 6 andalso Char.isSpace (String.sub (trim c, 6)))
                then go (rest, l :: acc)
                else
                  let
                    (* the declaration's lines: until its parentheses close *)
                    fun take (n, ls, more) =
                      if n <= 0 then (List.rev more, ls)
                      else case ls of
                             [] => (List.rev more, [])
                           | x :: xs => (case code x of
                                           SOME cx => take (n + openParens cx, xs, cx :: more)
                                         | NONE => (List.rev more, ls))
                    val (conts, rest') = take (openParens c, rest, [])
                    val whole = String.concatWith " " (List.map trim (c :: conts))
                    val indent = String.substring (c, 0, size c - size (Substring.string (Substring.dropl Char.isSpace (Substring.full c))))
                    val bird = if lhs then "> " else ""
                  in
                    case Option.mapPartial (rewrite (imap, exportsOf)) (parse whole) of
                      NONE => go (rest, l :: acc)
                    | SOME new => go (rest', List.rev (bird ^ indent ^ new :: List.map (fn _ => if lhs then ">" else "") conts) @ acc)
                  end
    in String.concatWith "\n" (go (ls, [])) end

  (* ---- the programs of 98's *)
  type program = {dir : string, name : string, main : string, files : string list, base : string}
  fun programsIn (root, dir) : program list =
    let
      val d = root ^ "/tests/hs/" ^ dir
      fun hs f = String.isSuffix ".hs" f orelse String.isSuffix ".lhs" f
    in
      List.mapPartial (fn n =>
        let val p = d ^ "/" ^ n
        in
          if Sh.isDir p then
            case List.find (fn m => Sh.exists (p ^ "/" ^ m)) ["Main.hs", "Main.lhs"] of
              SOME m => SOME {dir = dir, name = n, main = p ^ "/" ^ m, files = List.filter hs (List.map (fn f => p ^ "/" ^ f) (Sh.sort (Sh.entries p))),
                              base = p}
            | NONE => NONE
          else if hs n then
            let val name = if String.isSuffix ".lhs" n then String.substring (n, 0, size n - 4) else String.substring (n, 0, size n - 3)
            in SOME {dir = dir, name = name, main = p, files = [p], base = d ^ "/" ^ name} end
          else NONE
        end) (Sh.sort (Sh.entries d))
    end

  val siblings = ["expected", "cargs", "args", "vmargs", "stdin", "exitcode", "stderr", "stderr-head", "cwarn", "typecheck-ok",
                  "typecheck-error"]

  (* whether a module imports a module of 98's library that 2010 renames or
     drops, by its import lines *)
  fun imports98 (imap, file) =
    let val lhs = String.isSuffix ".lhs" file
    in
      List.exists (fn l =>
        let val c = if lhs then (if String.isPrefix "> " l then String.extract (l, 2, NONE) else "") else l
        in case parse (trim c) of
             SOME d => (case List.find (fn (m, _) => m = #module d) imap of SOME (m, bs) => bs <> [m] | NONE => false)
           | NONE => false
        end) (String.fields (fn c => c = #"\n") (Sh.read file))
    end

  (* ---- writing *)
  fun replaceAll (text, from, to) =
    let
      val n = size from
      fun go (i, start, acc) =
        if i > size text - n then String.concat (List.rev (String.extract (text, start, NONE) :: acc))
        else if String.substring (text, i, n) = from then go (i + n, i + n, to :: String.substring (text, start, i - start) :: acc)
        else go (i + 1, start, acc)
    in if n = 0 orelse size text < n then text else go (0, 0, []) end

  fun main args =
    let
      fun opt (name, []) = NONE
        | opt (name, x :: y :: rest) = if x = name then SOME y else opt (name, y :: rest)
        | opt (name, [_]) = NONE
      val out = case opt ("--out", args) of SOME d => d | NONE => raise MeasureCommon.Usage "hs2010-programs --out DIR [--root ROOT]"
      val root = getOpt (opt ("--root", args), Sh.root)
      val rows = table root
      val imap = importMap rows
      val exportsCache = List.concat (List.map (fn (_, bs) => List.map (fn b => (b, exportsOf rows b)) bs) imap)
      fun exportsOfModule b = case List.find (fn (x, _) => x = b) exportsCache of SOME (_, xs) => xs | NONE => []
      val readingsOf = fn id => case List.find (fn (r : row) => #id r = id) rows of SOME r => #reading r | NONE => []
      val generated = ref [] : string list ref
      val skipped = ref [] : string list ref
      val names = ref [] : string list ref
      (* a program of 98's is written for 2010 where it imports a module
         2010 renames or drops, or names a row 2010 renames *)
      fun one (p : program) =
        let
          val text = Sh.read (#main p)
          val first = firstLineOf text
          val words = getOpt (rowsWords first, [])
          val nameId = hd (String.fields (fn c => c = #"_") (#name p))
          val ids = nameId :: List.filter (fn w => not (isReading w) andalso w <> "deviation") words
        in
          if not (List.exists (fn f => imports98 (imap, f)) (#files p) orelse List.exists (isSome o renamedFrom rows) ids) then ()
          else
          let
            val suffix = String.extract (#name p, size nameId, NONE)
            val mapped = List.map (mapId rows) ids
            val newName = hd mapped ^ suffix
            val () = if member (#dir p ^ "/" ^ newName) (!names) then raise Skip ("another program is written as " ^ newName) else ()
            val carried = List.concat (List.map readingsOf mapped)
            val pins = List.filter isReading words
            val kept = List.filter (fn r => member r carried) pins
            val dropped = List.filter (fn r => not (member r carried)) pins @ (if member "deviation" words then ["deviation"] else [])
            val rewritten = List.map (fn f => (f, rewriteModule (imap, exportsOfModule) (Sh.read f, String.isSuffix ".lhs" f))) (#files p)
            val oldPath = "tests/hs/" ^ #dir p ^ "/" ^ #name p
            val newPath = "tests/hs2010/" ^ #dir p ^ "/" ^ newName
            (* the first line, its rows made 2010's *)
            fun firstOf (f, t) =
              if f <> #main p orelse not (isSome (rowsWords first)) then t
              else
                let val lhsBird = if String.isPrefix "> " first then "> " else ""
                    val line = lhsBird ^ "-- rows:" ^ String.concat (List.map (fn w => " " ^ w) (tl mapped @ kept))
                in line ^ String.extract (t, size (firstLineOf t), NONE) end
            val target = out ^ "/" ^ #dir p
            val () = Sh.mkdirs target
            val () =
              if Sh.isDir (#base p) then
                List.app (fn (f, t) => (Sh.mkdirs (target ^ "/" ^ newName);
                                        Sh.write (target ^ "/" ^ newName ^ "/" ^ OS.Path.file f, firstOf (f, t)))) rewritten
              else List.app (fn (f, t) => Sh.write (target ^ "/" ^ newName ^ (if String.isSuffix ".lhs" f then ".lhs" else ".hs"),
                                                    firstOf (f, t))) rewritten
            val dirBase = root ^ "/tests/hs/" ^ #dir p ^ "/" ^ #name p
            val () = List.app (fn e => let val s = dirBase ^ "." ^ e
                                       in if Sh.exists s then Sh.write (target ^ "/" ^ newName ^ "." ^ e,
                                                                        replaceAll (Sh.read s, oldPath, newPath)) else () end) siblings
          in
            names := (#dir p ^ "/" ^ newName) :: !names;
            generated := String.concatWith "\t" [#dir p, #name p, newName, String.concatWith " " mapped,
                                                 if null dropped then "-" else "dropped " ^ String.concatWith " " dropped] :: !generated
          end
          handle Skip why => skipped := String.concatWith "\t" [#dir p, #name p, why] :: !skipped
        end
      val () = List.app (fn d => List.app one (programsIn (root, d))) ["lang", "accept", "errors"]
      val () = Sh.mkdirs out
      val () = Sh.write (out ^ "/generated.tsv", "dir\tprogram98\tprogram2010\trows\tnote\n"
                                                ^ String.concat (List.map (fn l => l ^ "\n") (List.rev (!generated))))
      val () = Sh.write (out ^ "/skipped.tsv", "dir\tprogram98\twhy\n" ^ String.concat (List.map (fn l => l ^ "\n") (List.rev (!skipped))))
    in
      Sh.say ("hs2010-programs: " ^ Int.toString (length (!generated)) ^ " programs written to " ^ out ^ ", "
              ^ Int.toString (length (!skipped)) ^ " left out (skipped.tsv); the import map: "
              ^ String.concatWith ", " (List.map (fn (m, bs) => m ^ " -> " ^ (if null bs then "-" else String.concatWith "+" bs)) imap)
              ^ "\n");
      0
    end
end
