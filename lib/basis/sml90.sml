(* SML90: the initial basis of the 1990 Definition, over Real.Math, String
   and TextIO. As in MLton's (unexposed) SML90, which Poly/ML agrees with:
   the arithmetic exceptions are Overflow and Mod is Div, which the Library
   raises in their place; Sqrt, Ln, Ord, Io and Interrupt are new, and
   sqrt, ln, ord and the functions on streams raise them. *)
structure SML90 =
struct
  type instream = TextIO.instream
  type outstream = TextIO.outstream

  exception Abs = Overflow
  exception Quot = Overflow
  exception Prod = Overflow
  exception Neg = Overflow
  exception Sum = Overflow
  exception Diff = Overflow
  exception Floor = Overflow
  exception Exp = Overflow
  exception Sqrt
  exception Ln
  exception Ord
  exception Mod = Div
  exception Io of string
  exception Interrupt

  fun sqrt x = if Real.< (x, 0.0) then raise Sqrt else Math.sqrt x
  fun exp x = let val y = Math.exp x in if Real.isFinite y then y else raise Exp end
  fun ln x = if Real.> (x, 0.0) then Math.ln x else raise Ln
  val sin = Math.sin
  val cos = Math.cos
  val arctan = Math.atan

  fun ord s = if String.size s = 0 then raise Ord else Char.ord (String.sub (s, 0))
  fun chr i = String.str (Char.chr i)
  fun explode s = List.map String.str (String.explode s)
  val implode = String.concat

  val std_in = TextIO.stdIn
  val std_out = TextIO.stdOut
  fun open_in name = TextIO.openIn name handle IO.Io _ => raise Io ("Cannot open " ^ name)
  fun open_out name = TextIO.openOut name handle IO.Io _ => raise Io ("Cannot open " ^ name)
  val close_in = TextIO.closeIn
  val close_out = TextIO.closeOut
  (* "" at the end of the stream, as a closed stream is *)
  fun lookahead ins = case TextIO.lookahead ins of SOME c => String.str c | NONE => ""
  fun input (ins, n) = TextIO.inputN (ins, n) handle IO.Io _ => raise Io "Cannot input"
  fun end_of_stream ins = TextIO.endOfStream ins handle IO.Io _ => true
  fun output (out, s) = TextIO.output (out, s) handle IO.Io _ => raise Io "Cannot output"
end
