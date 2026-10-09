(* Compiler: what the REPL sets for the program it runs (docs/repl.md), and
   the printers it makes call. Rune's own, not of the specification.

   The REPL is one program with the code it compiles, and they share this
   library: the REPL puts its `use` into `useHook` when it starts, and the
   code it compiles calls `Compiler.use`, which is the same structure. A
   program compiled by `rune` has nothing in the hook. *)
structure RuneCompiler =
struct
  val useHook : (string -> unit) ref =
    ref (fn _ => raise Fail "Compiler.use: this program has no compiler beside it (rune-repl has)")
  fun use file = !useHook file
  val printDepth = ref 20
  val prompt1 = ref "- "
  val prompt2 = ref "= "
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
  fun echo (name : string, shown : string, ty : string) = print ("val " ^ name ^ " = " ^ shown ^ " : " ^ ty ^ "\n")
end

(* Compiler: what a program can ask of the compiler it runs beside.

   Implements: COMPILER

   Status: extension *)
structure Compiler = RuneCompiler
