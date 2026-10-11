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
  val compileHook : ({read : unit -> char option, file : string, line : int} -> unit -> unit) ref =
    ref (fn _ => raise Fail "Compiler.compile: this program has no compiler beside it (rune-repl has)")
  fun compile r = !compileHook r
  val printDepth = ref 20
  val prompt1 = ref "- "
  val prompt2 = ref "= "
  (* what the REPL writes for a value a declaration bound: its name, the
     value shown and its type; the REPL styles it on a terminal *)
  val echoHook : (string * string * string -> unit) ref =
    ref (fn (name, shown, ty) => print ("val " ^ name ^ " = " ^ shown ^ " : " ^ ty ^ "\n"))

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

  (* the REPL's printers: an application of it is, where the REPL compiles,
     a call of RuneShow.addPrinterAt with the name of the type (Translate) *)
  val addPrettyPrinter = _prim "repl_printer_add" : (int -> 'a -> 'b -> pretty) -> unit
end

(* RuneShow: the pieces of the printers the REPL makes for each value it
   shows (src/repl/show.sml): one for each type, given the depth left, at
   which a value prints as `...`, and the value. *)
structure RuneShow =
struct
  fun cut (d : int, f : unit -> string) : string = if d <= 0 then "..." else f ()

  (* an argument of a constructor, or of ref, in parentheses where it is
     itself an application *)
  fun arg (s : string) : string =
    if CharVector.exists (fn c => c = #" ") s
       andalso not (CharVector.exists (fn c => c = String.sub (s, 0)) "([{\"#")
    then "(" ^ s ^ ")" else s

  fun int (_ : int) (i : int) = Int.toString i
  fun word (_ : int) (w : word) = "0wx" ^ Word.toString w
  fun real (_ : int) (r : real) = Real.toString r
  fun char (_ : int) (c : char) = "#\"" ^ Char.toString c ^ "\""
  fun string (_ : int) (s : string) = "\"" ^ String.toString s ^ "\""
  fun unit (_ : int) () = "()"
  fun function (_ : int) (_ : 'a) = "fn"
  fun hidden (_ : int) (_ : 'a) = "?"
  fun exn (_ : int) (e : exn) = General.exnName e
  fun list (f : int -> 'a -> string) (d : int) (xs : 'a list) =
    cut (d, fn () => "[" ^ String.concatWith ", " (List.map (f (d - 1)) xs) ^ "]")
  fun tuple (d : int) (fs : (int -> string) list) =
    cut (d, fn () => "(" ^ String.concatWith ", " (List.map (fn f => f (d - 1)) fs) ^ ")")
  fun record (d : int) (fs : (string * (int -> string)) list) =
    cut (d, fn () => "{" ^ String.concatWith ", " (List.map (fn (l, f) => l ^ " = " ^ f (d - 1)) fs) ^ "}")
  fun con0 (name : string) = name
  fun con1 (d : int) (name : string, f : int -> string) = cut (d, fn () => name ^ " " ^ arg (f (d - 1)))
  fun reference (f : int -> 'a -> string) (d : int) (r : 'a ref) = cut (d, fn () => "ref " ^ arg (f (d - 1) (!r)))
  fun array (f : int -> 'a -> string) (d : int) (a : 'a array) =
    cut (d, fn () => "fromList[" ^ String.concatWith ", " (Array.foldr (fn (x, l) => f (d - 1) x :: l) [] a) ^ "]")
  fun vector (f : int -> 'a -> string) (d : int) (v : 'a vector) =
    cut (d, fn () => "#[" ^ String.concatWith ", " (Vector.foldr (fn (x, l) => f (d - 1) x :: l) [] v) ^ "]")
  (* a value bound by a declaration, as the REPL echoes it *)
  fun echo (name : string, shown : string, ty : string) = !RuneCompiler.echoHook (name, shown, ty)

  (* The printers of Compiler.addPrettyPrinter, by the name of their type
     (UnitBasis.stableName), each kept at a type of its own and taken out at
     the one it was put in at: the REPL asks for one by the type it is
     making a printer for. *)
  val cast = _prim "unsafe_cast" : 'a -> 'b
  val printers : (string * (int -> unit -> unit -> RuneCompiler.pretty)) list ref = ref []
  fun addPrinterAt (key : string, f : int -> 'a -> 'b -> RuneCompiler.pretty) : unit =
    printers := (key, cast f) :: List.filter (fn (k, _) => k <> key) (!printers)
  fun hasPrinter (key : string) : bool = List.exists (fn (k, _) => k = key) (!printers)
  fun render (p : RuneCompiler.pretty) : string =
    let val parts = ref []
    in RuneCompiler.prettyPrint (fn s => parts := s :: !parts, !RuneCompiler.lineLength) p;
       String.concat (List.rev (!parts))
    end
  (* the printer of the type key names, given how to show its arguments *)
  fun installed (key : string, args : 'a) (d : int) (v : 'b) : string =
    case List.find (fn (k, _) => k = key) (!printers) of
      SOME (_, p) => render ((cast p : int -> 'a -> 'b -> RuneCompiler.pretty) d args v)
    | NONE => "?"
  (* an argument of the type, as a printer of the type is given it *)
  fun argument (f : int -> 'a -> string) : 'a * int -> RuneCompiler.pretty =
    fn (v, d) => RuneCompiler.PrettyString (f d v)
end

(* Compiler: what a program can ask of the compiler it runs beside.

   Implements: COMPILER

   Status: extension *)
structure Compiler = RuneCompiler
