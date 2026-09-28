(* Mutants of a source file of the Basis Library (docs/plans/quickcheck.md,
   M9: the adequacy of the laws). A mutant changes one token of the file's
   code, never of a comment, a string or a character, into another that
   usually keeps the program well typed: a comparison into its neighbour
   (`<` and `<=`, `>` and `>=`, `<>` into `=`), `+` and `-` into each other,
   `andalso` and `orelse` into each other, `true` and `false` into each other,
   the literals 0 and 1 into each other, and the exception a `raise` names
   into another.
     mutate FILE        the sites: one line `k line:column token -> replacement`
     mutate FILE k      the file with site k changed, on standard output
   tests/basis/run-mutants.sh runs the laws against each. *)

(* the file's tokens that are code, as (offset, text) *)
fun tokens (s : string) : (int * string) list =
  let
    val n = String.size s
    fun at i = if i < n then String.sub (s, i) else #"\000"
    fun symbolic c = CharVector.exists (fn d => d = c) "!%&$#+-/:<=>?@\\~`^|*"
    fun alnum c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"
    (* the end of a comment that opens at i, nested *)
    fun comment (i, depth) =
      if i >= n then n
      else if at i = #"(" andalso at (i + 1) = #"*" then comment (i + 2, depth + 1)
      else if at i = #"*" andalso at (i + 1) = #")" then (if depth = 1 then i + 2 else comment (i + 2, depth - 1))
      else comment (i + 1, depth)
    (* the end of a string that opens at i *)
    fun string i =
      if i >= n then n
      else if at i = #"\\" then string (i + 2)
      else if at i = #"\"" then i + 1
      else string (i + 1)
    fun span (i, p) = if i < n andalso p (at i) then span (i + 1, p) else i
    fun go (i, acc) =
      if i >= n then List.rev acc
      else if at i = #"(" andalso at (i + 1) = #"*" then go (comment (i, 0), acc)
      else if at i = #"\"" then go (string (i + 1), acc)
      else if at i = #"#" andalso at (i + 1) = #"\"" then go (string (i + 2), acc)
      else if Char.isSpace (at i) then go (i + 1, acc)
      else if alnum (at i) then let val j = span (i, fn c => alnum c orelse c = #".") in go (j, (i, String.substring (s, i, j - i)) :: acc) end
      else if symbolic (at i) then let val j = span (i, symbolic) in go (j, (i, String.substring (s, i, j - i)) :: acc) end
      else go (i + 1, (i, String.str (at i)) :: acc)
  in
    go (0, [])
  end

val exceptions = ["Subscript", "Size", "Overflow", "Div", "Domain", "Chr", "Empty", "Option", "Span"]

(* the replacement of a token, given the token before it *)
fun replacement (prev : string, t : string) : string option =
  case t of
    "<" => SOME "<=" | "<=" => SOME "<" | ">" => SOME ">=" | ">=" => SOME ">" | "<>" => SOME "="
  | "+" => SOME "-" | "-" => SOME "+"
  | "andalso" => SOME "orelse" | "orelse" => SOME "andalso"
  | "true" => SOME "false" | "false" => SOME "true"
  | "0" => SOME "1" | "1" => SOME "0"
  | _ =>
      if prev = "raise" andalso List.exists (fn e => e = t) exceptions
      then SOME (if t = "Domain" then "Subscript" else "Domain")
      else NONE

fun sites (s : string) : (int * string * string) list =
  let
    val ts = tokens s
    val befores = "" :: List.map #2 ts
  in
    List.mapPartial (fn ((i, t), b) => Option.map (fn r => (i, t, r)) (replacement (b, t)))
                    (ListPair.zip (ts, List.take (befores, List.length ts)))
  end

fun lineCol (s : string, i : int) : int * int =
  let
    fun go (k, line, col) = if k >= i then (line, col)
                            else if String.sub (s, k) = #"\n" then go (k + 1, line + 1, 1)
                            else go (k + 1, line, col + 1)
  in go (0, 1, 1) end

fun readFile (path : string) : string =
  let val ins = TextIO.openIn path in TextIO.inputAll ins before TextIO.closeIn ins end

val () =
  case CommandLine.arguments () of
    [file] =>
      let val s = readFile file
      in
        List.app (fn (k, (i, t, r)) =>
                    let val (l, c) = lineCol (s, i)
                    in print (Int.toString k ^ " " ^ Int.toString l ^ ":" ^ Int.toString c ^ " " ^ t ^ " -> " ^ r ^ "\n") end)
                 (ListPair.zip (List.tabulate (List.length (sites s), fn k => k + 1), sites s))
      end
  | [file, k] =>
      let
        val s = readFile file
        val (i, t, r) = List.nth (sites s, valOf (Int.fromString k) - 1)
      in
        print (String.substring (s, 0, i) ^ r ^ String.extract (s, i + String.size t, NONE))
      end
  | _ => (TextIO.output (TextIO.stdErr, "usage: mutate FILE [K]\n"); OS.Process.exit OS.Process.failure)
