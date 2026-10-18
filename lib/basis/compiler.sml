(* Compiler: what the REPL sets for the program it runs (docs/repl.md), and
   the printers it makes call. Rune's own, not of the specification.

   The REPL is one program with the code it compiles, and they share this
   library: the REPL puts its `use` and its `compile` into the hooks when
   it starts, and the code it compiles calls `Compiler.use`, which is the
   same structure. A program compiled by `rune` has nothing in the hooks. *)
structure RuneCompiler =
struct
  val useHook : (string -> unit) ref =
    ref (fn _ => raise Fail "Compiler.use: this program has no compiler beside it (rune-repl has)")
  fun use file = !useHook file
  (* the mode, by its name, and the reader *)
  val compileHook : (string -> {read : unit -> char option, file : string, line : int} -> unit -> unit) ref =
    ref (fn _ => fn _ => raise Fail "Compiler.compile: this program has no compiler beside it (rune-repl has)")
  fun compileIn mode r = !compileHook mode r
  fun compile r = compileIn "ascii" r
  val printDepth = ref 20
  val prompt1 = ref "- "
  val prompt2 = ref "= "

  type location = {file : string, startLine : int, startPosition : int, endLine : int, endPosition : int}
  datatype context = ContextLocation of location | ContextProperty of string * string
  datatype pretty =
      PrettyBlock of int * bool * context list * pretty list
    | PrettyBreak of int * int
    | PrettyLineBreak
    | PrettyString of string
    | PrettyStringWithWidth of string * int

  fun prettySize (p : pretty) : int =
    case p of
      PrettyString s => String.size s
    | PrettyStringWithWidth (_, w) => w
    | PrettyBreak (b, _) => b
    | PrettyLineBreak => 0
    | PrettyBlock (_, _, _, ps) => List.foldl (fn (q, n) => n + prettySize q) 0 ps

  (* A block on one line where it fits; where not, consistent breaks all
     of its breaks, and inconsistent each whose next stretch -- up to the
     block's next break -- would not fit on the line *)
  fun prettyPrint (out : string -> unit, width : int) (p : pretty) : unit =
    let
      val col = ref 0
      fun spaces n = if n <= 0 then "" else CharVector.tabulate (n, fn _ => #" ")
      fun text (s, w) = (out s; col := !col + w)
      fun newline n = (out ("\n" ^ spaces n); col := Int.max (n, 0))
      fun stretch [] = 0
        | stretch (PrettyBreak _ :: _) = 0
        | stretch (PrettyLineBreak :: _) = 0
        | stretch (q :: rest) = prettySize q + stretch rest
      fun lay (q, outer) =
        case q of
          PrettyString s => text (s, String.size s)
        | PrettyStringWithWidth (s, w) => text (s, w)
        | PrettyBreak (b, _) => text (spaces b, b)
        | PrettyLineBreak => newline outer
        | PrettyBlock (ind, consistent, _, items) =>
            let
              val start = !col
              val fits = start + prettySize q <= width
              fun go [] = ()
                | go (PrettyBreak (b, off) :: rest) =
                    ((if fits orelse (not consistent andalso !col + b + stretch rest <= width)
                      then text (spaces b, b) else newline (start + ind + off));
                     go rest)
                | go (PrettyLineBreak :: rest) = (newline (start + ind); go rest)
                | go (r :: rest) = (lay (r, start + ind); go rest)
            in go items end
    in lay (p, 0) end

  val lineLength = ref 80

  (* the limits of what the REPL prints of a value (RuneShow) *)
  val printLength = ref 100
  val stringLength = ref 1000
  val printNodes = ref 10000

  (* how much the REPL says of a declaration: "normal", "concise" (values,
     no declarations of types), "verbose" (structures' signatures too) or
     "silent" (docs/plans/repl.md, D16) *)
  val feedback = ref "normal"

  (* what the REPL writes for a value a declaration bound: its name, the
     value shown and its type; the REPL lays it out and styles it *)
  val echoHook : (string * pretty * string -> unit) ref =
    ref (fn (name, shown, ty) =>
           let val parts = ref []
           in prettyPrint (fn s => parts := s :: !parts, !lineLength) shown;
              print ("val " ^ name ^ " = " ^ String.concat (List.rev (!parts)) ^ " : " ^ ty ^ "\n")
           end)

  (* the REPL's printers: an application of it is, where the REPL compiles,
     a call of RuneShow.addPrinterAt with the name of the type (Translate) *)
  val addPrettyPrinter = _prim "repl_printer_add" : (int -> 'a -> 'b -> pretty) -> unit
end

(* RuneShow: the pieces of the printers the REPL makes for each value it
   shows (src/repl/show.sml): one for each type, given the depth left, at
   which a value prints as `...`, and the value, to a document
   (RuneCompiler.pretty) that the REPL lays out at the terminal's width
   (docs/plans/repl.md, D16). A part of a value carries its role of the
   palette -- a number, a string, a constructor -- as a ContextProperty
   ("role", ...), which the REPL styles by and prettyPrint ignores.

   Four limits cut a value short with `...`: the depth (printDepth), the
   items of a list, an array or a vector (printLength), the characters of
   a string (stringLength), and the parts of the whole value
   (printNodes). *)
structure RuneShow =
struct
  type pretty = RuneCompiler.pretty

  fun str (s : string) : pretty = RuneCompiler.PrettyString s

  (* text in a role of the palette *)
  fun role (r : string, s : string) : pretty =
    RuneCompiler.PrettyBlock (0, false, [RuneCompiler.ContextProperty ("role", r)], [str s])

  val dots : pretty = role ("repl.ui", "...")

  (* the parts of the value being shown that are left to show *)
  val budget = ref 0

  (* a part: `...` where the depth or the budget is spent *)
  fun cut (d : int, f : unit -> pretty) : pretty =
    if d <= 0 orelse !budget <= 0 then dots else (budget := !budget - 1; f ())

  (* the items between brackets, each after a comma and a break, aligned
     after the opening: on one line where they fit, and else, for a tuple
     or a record (consistent), one to a line, and for a list, an array or a
     vector, as many to a line as fit *)
  fun sequence' (consistent : bool) (opening : string, closing : string, items : pretty list) : pretty =
    let
      fun sep [] = []
        | sep [x] = [x]
        | sep (x :: rest) = x :: str "," :: RuneCompiler.PrettyBreak (1, 0) :: sep rest
    in
      RuneCompiler.PrettyBlock (size opening, consistent, [], str opening :: sep items @ [str closing])
    end
  val sequence = sequence' true
  val filled = sequence' false

  (* the first printLength items, and `...` for the rest *)
  fun limited (n : int, item : int -> pretty) : pretty list =
    let
      val shown = Int.min (n, Int.max (0, !RuneCompiler.printLength))
      fun go k =
        if k >= shown then (if n > shown then [dots] else [])
        else if !budget <= 0 then [dots]
        else item k :: go (k + 1)
    in go 0 end

  (* the text of a document on one line, to tell whether it needs
     parentheses as an argument *)
  fun flat (p : pretty) : string =
    case p of
      RuneCompiler.PrettyString s => s
    | RuneCompiler.PrettyStringWithWidth (s, _) => s
    | RuneCompiler.PrettyBreak (b, _) => CharVector.tabulate (b, fn _ => #" ")
    | RuneCompiler.PrettyLineBreak => " "
    | RuneCompiler.PrettyBlock (_, _, _, ps) => String.concat (List.map flat ps)

  (* an argument of a constructor, or of ref, in parentheses where it is
     itself an application *)
  fun arg (p : pretty) : pretty =
    let val s = flat p
    in
      if CharVector.exists (fn c => c = #" ") s
         andalso not (CharVector.exists (fn c => c = String.sub (s, 0)) "([{\"#")
      then RuneCompiler.PrettyBlock (1, false, [], [str "(", p, str ")"]) else p
    end

  (* a real as it reads back as a real: with a point or an exponent *)
  fun realText (r : real) : string =
    let val s = Real.toString r
    in if CharVector.exists (fn c => c = #"." orelse c = #"E" orelse c = #"e" orelse c = #"n" orelse c = #"i") s
       then s else s ^ ".0"
    end

  fun int (_ : int) (i : int) = role ("syn.number", Int.toString i)
  fun word (_ : int) (w : word) = role ("syn.number", "0wx" ^ Word.toString w)
  fun real (_ : int) (r : real) = role ("syn.number", realText r)
  fun char (_ : int) (c : char) = role ("syn.string", "#\"" ^ Char.toString c ^ "\"")
  fun string (_ : int) (s : string) =
    if size s <= Int.max (0, !RuneCompiler.stringLength) then role ("syn.string", "\"" ^ String.toString s ^ "\"")
    else RuneCompiler.PrettyBlock (0, false, [],
           [role ("syn.string", "\"" ^ String.toString (String.substring (s, 0, Int.max (0, !RuneCompiler.stringLength))) ^ "\""),
            dots])
  fun unit (_ : int) () = str "()"
  fun function (_ : int) (_ : 'a) = role ("syn.keyword", "fn")
  fun hidden (_ : int) (_ : 'a) = role ("repl.ui", "?")
  fun list (f : int -> 'a -> pretty) (d : int) (xs : 'a list) =
    cut (d, fn () =>
      let
        val n = List.length xs
        val v = Vector.fromList (List.take (xs, Int.min (n, Int.max (0, !RuneCompiler.printLength))))
      in filled ("[", "]", limited (n, fn k => f (d - 1) (Vector.sub (v, k)))) end)
  fun tuple (d : int) (fs : (int -> pretty) list) =
    cut (d, fn () => sequence ("(", ")", List.map (fn f => f (d - 1)) fs))
  fun record (d : int) (fs : (string * (int -> pretty)) list) =
    cut (d, fn () => sequence ("{", "}", List.map (fn (l, f) =>
                                                    RuneCompiler.PrettyBlock (2, false, [],
                                                      [str (l ^ " ="), RuneCompiler.PrettyBreak (1, 0), f (d - 1)])) fs))
  fun con0 (name : string) = role ("syn.constructor", name)
  fun con1 (d : int) (name : string, f : int -> pretty) =
    cut (d, fn () => RuneCompiler.PrettyBlock (2, false, [], [role ("syn.constructor", name), RuneCompiler.PrettyBreak (1, 0),
                                                              arg (f (d - 1))]))
  fun reference (f : int -> 'a -> pretty) (d : int) (r : 'a ref) =
    cut (d, fn () => RuneCompiler.PrettyBlock (2, false, [], [role ("syn.constructor", "ref"), RuneCompiler.PrettyBreak (1, 0),
                                                              arg (f (d - 1) (!r))]))
  fun array (f : int -> 'a -> pretty) (d : int) (a : 'a array) =
    cut (d, fn () => filled ("fromList[", "]", limited (Array.length a, fn k => f (d - 1) (Array.sub (a, k)))))
  fun vector (f : int -> 'a -> pretty) (d : int) (v : 'a vector) =
    cut (d, fn () => filled ("#[", "]", limited (Vector.length v, fn k => f (d - 1) (Vector.sub (v, k)))))

  (* Exceptions with their arguments: the REPL registers a printer for each
     exception constructor a declaration declares, made where the
     constructor is in scope, and one for each of the Basis's; the newest
     that takes an exception shows it, and one that none takes shows by its
     name (docs/plans/repl.md, M7) *)
  val exnPrinters : (int -> exn -> pretty option) list ref = ref []
  fun addExn (p : int -> exn -> pretty option) : unit = exnPrinters := p :: !exnPrinters
  fun exn (d : int) (e : exn) : pretty =
    let
      fun first [] = role ("syn.constructor", General.exnName e)
        | first (p :: rest) = case p d e of SOME shown => shown | NONE => first rest
    in first (!exnPrinters) end

  (* a value bound by a declaration, as the REPL echoes it: the value made
     with a fresh budget *)
  fun echo (name : string, shown : unit -> pretty, ty : string) =
    (budget := !RuneCompiler.printNodes; !RuneCompiler.echoHook (name, shown (), ty))

  (* The printers of Compiler.addPrettyPrinter, by the name of their type
     (UnitBasis.stableName), each kept at a type of its own and taken out at
     the one it was put in at: the REPL asks for one by the type it is
     making a printer for. *)
  val cast = _prim "unsafe_cast" : 'a -> 'b
  val printers : (string * (int -> unit -> unit -> RuneCompiler.pretty)) list ref = ref []
  fun addPrinterAt (key : string, f : int -> 'a -> 'b -> RuneCompiler.pretty) : unit =
    printers := (key, cast f) :: List.filter (fn (k, _) => k <> key) (!printers)
  fun hasPrinter (key : string) : bool = List.exists (fn (k, _) => k = key) (!printers)
  (* the printer of the type key names, given how to show its arguments *)
  fun installed (key : string, args : 'a) (d : int) (v : 'b) : pretty =
    case List.find (fn (k, _) => k = key) (!printers) of
      SOME (_, p) => (cast p : int -> 'a -> 'b -> RuneCompiler.pretty) d args v
    | NONE => hidden d v
  (* an argument of the type, as a printer of the type is given it *)
  fun argument (f : int -> 'a -> pretty) : 'a * int -> RuneCompiler.pretty = fn (v, d) => f d v
end

(* Compiler: what a program can ask of the compiler it runs beside.

   Implements: COMPILER

   Status: extension *)
structure Compiler = RuneCompiler
