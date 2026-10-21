(* Independent bytecode fixtures for the native/VM tests. Layout and opcode
   numbers come from the generated .def files; deliberately invalid fields
   are written here rather than through the production bytecode writer. *)
structure BytecodeFixture =
struct
  open Sh
  exception Bad of string
  fun number text = case IntInf.fromString text of SOME n => n | NONE => raise Bad ("not an integer: " ^ text)
  fun le bytes value =
    let
      val modulus = IntInf.pow (2, 8 * bytes)
      val n = if value < 0 then value + modulus else value
      fun go (0, _, acc) = String.implode (List.rev acc)
        | go (left, n, acc) = go (left - 1, IntInf.div (n, 256), Char.chr (IntInf.toInt (IntInf.mod (n, 256))) :: acc)
    in if n < 0 orelse n >= modulus then raise Bad "integer does not fit its fixture field" else go (bytes, n, []) end
  fun u32 n = le 4 (IntInf.fromInt n)
  fun text s = u32 (size s) ^ s
  fun header defs =
    case List.find (String.isPrefix "# rbc header ") (lines (read (fromRoot defs))) of
      SOME s => (case String.fromCString (String.extract (s, 13, NONE)) of SOME h => h | NONE => raise Bad "invalid bytecode header escapes")
    | NONE => raise Bad (defs ^ ": missing bytecode header")
  fun definitions file =
    List.map (String.tokens Char.isSpace)
      (List.filter (fn s => not (String.isPrefix "#" s) andalso not (CharVector.all Char.isSpace s)) (lines (read (fromRoot file))))
  fun withoutComment line = Substring.string (#1 (Substring.position "#" (Substring.full line)))
  fun literal raw =
    let fun go (i, acc) =
          if i >= size raw then String.implode (List.rev acc)
          else if i + 1 < size raw andalso String.sub (raw, i) = #"\\" andalso String.sub (raw, i + 1) = #"n"
          then go (i + 2, #"\n" :: acc) else go (i + 1, String.sub (raw, i) :: acc)
    in go (0, []) end
  fun assemble {opdefs, primdefs, listing} =
    let
      val ops = ListPair.zip (definitions opdefs, List.tabulate (length (definitions opdefs), fn i => i))
      val prims = ListPair.zip (List.map hd (definitions primdefs), List.tabulate (length (definitions primdefs), fn i => i))
      fun opInfo name =
        case List.find (fn (fields, _) => hd fields = name) ops of
          SOME (fields, n) => (n, List.nth (fields, 1))
        | NONE => raise Bad ("unknown opcode " ^ name)
      fun lookup what key values = case List.find (fn (name, _) => name = key) values of
                                    SOME (_, n) => n | NONE => raise Bad ("unknown " ^ what ^ " " ^ key)
      val constants = ref [] : (string * string) list ref
      val globals = ref 0
      val functions = ref [] : (string * int * int) list ref
      val labels = ref [] : (string * int) list ref
      val instructions = ref [] : (string * string list) list ref
      val pc = ref 0
      fun first line =
        let val line = withoutComment line
            val fields = String.tokens Char.isSpace line
        in
          case fields of
            [] => ()
          | ["const", name, "int", n] => constants := !constants @ [(name, str (Char.chr 0) ^ le 8 (number n))]
          | "const" :: name :: "string" :: _ =>
              let val quoted = Substring.string (Substring.dropr Char.isSpace
                                  (#2 (Substring.position "\"" (Substring.full line))))
                  val raw = if size quoted >= 2 andalso String.isSuffix "\"" quoted
                            then String.substring (quoted, 1, size quoted - 2)
                            else raise Bad ("unclosed string constant " ^ name)
                  val value = literal raw
              in constants := !constants @ [(name, str (Char.chr 3) ^ text value)] end
          | ["globals", n] => globals := IntInf.toInt (number n)
          | ["function", name, locals] => functions := !functions @ [(name, !pc, IntInf.toInt (number locals))]
          | [label] =>
              if String.isSuffix ":" label then labels := (String.substring (label, 0, size label - 1), !pc) :: !labels
              else instruction fields
          | _ => instruction fields
        end
      and instruction fields =
        let val name = hd fields
            val args = tl fields
            val (_, spec) = opInfo name
            val list = String.isSuffix "..." spec
            val count = if spec = "-" then 0 else length (String.fields (fn c => c = #",") spec)
        in
          if list orelse length args = count then () else raise Bad ("wrong operand count for " ^ name);
          instructions := (name, args) :: !instructions;
          pc := !pc + 1 + 4 * length args
        end
      val () = List.app first (String.fields (fn c => c = #"\n") (read listing))
      val constIndex = ListPair.zip (List.map #1 (!constants), List.tabulate (length (!constants), fn i => i))
      val funIndex = ListPair.zip (List.map #1 (!functions), List.tabulate (length (!functions), fn i => i))
      fun emit (name, args) =
        let val (opcode, spec) = opInfo name
            val primitive = String.isPrefix "p" spec
            fun arg (i, s) =
              if primitive andalso i = 0 then u32 (lookup "primitive" s prims)
              else if String.isPrefix "@" s then u32 (lookup "label" (String.extract (s, 1, NONE)) (!labels))
              else if String.isPrefix "%" s then u32 (lookup "constant" (String.extract (s, 1, NONE)) constIndex)
              else if String.isPrefix "&" s then u32 (lookup "function" (String.extract (s, 1, NONE)) funIndex)
              else le 4 (number s)
        in str (Char.chr opcode) ^ String.concat (List.map arg (ListPair.zip (List.tabulate (length args, fn i => i), args))) end
      val code = String.concat (List.map emit (List.rev (!instructions)))
    in
      header opdefs ^ u32 (length (!constants)) ^ String.concat (List.map #2 (!constants))
      ^ u32 (!globals) ^ u32 (length (!functions))
      ^ String.concat (List.map (fn (name, offset, locals) => u32 offset ^ u32 locals ^ text name) (!functions))
      ^ u32 (size code) ^ code ^ String.concat (List.tabulate (7, fn _ => u32 0))
    end

  (* C's default %g: six significant digits, scientific notation below
     1e-4 or from 1e6, two exponent digits, and the sign of negative zero.
     Real.fmt GEN chooses the shorter notation, so use SCI for rounding and
     apply C's notation rule here. *)
  fun finiteG r =
    let
      val scientific = Real.fmt (StringCvt.SCI (SOME 5)) r
      val (mantissa, exponent) =
        case String.fields (fn c => c = #"E" orelse c = #"e") scientific of
          [m, e] => (m, case Int.fromString e of SOME n => n | NONE => raise Bad "invalid formatted exponent")
        | _ => raise Bad "invalid formatted real"
      val negative = String.isPrefix "~" mantissa orelse String.isPrefix "-" mantissa
      val digits = String.translate (fn #"." => "" | #"~" => "" | #"-" => "" | c => str c) mantissa
      fun trim s = Substring.string (Substring.dropr (fn c => c = #"0") (Substring.full s))
      val digits = let val s = trim digits in if s = "" then "0" else s end
      fun zeros n = String.implode (List.tabulate (Int.max (0, n), fn _ => #"0"))
      val body =
        if exponent < ~4 orelse exponent >= 6 then
          str (String.sub (digits, 0)) ^ (if size digits = 1 then "" else "." ^ String.extract (digits, 1, NONE))
          ^ "e" ^ (if exponent < 0 then "-" else "+")
          ^ StringCvt.padLeft #"0" 2 (Int.toString (Int.abs exponent))
        else if exponent < 0 then "0." ^ zeros (~exponent - 1) ^ digits
        else if size digits <= exponent + 1 then digits ^ zeros (exponent + 1 - size digits)
        else String.substring (digits, 0, exponent + 1) ^ "." ^ String.extract (digits, exponent + 1, NONE)
    in (if negative then "-" else "") ^ body end
  fun realG value =
    case Real.fromString value of
      NONE => raise Bad ("invalid real constant " ^ value)
    | SOME r => if Real.isNan r then "nan"
                else if not (Real.isFinite r) then (if r < 0.0 then "-inf" else "inf")
                else finiteG r
  fun normalizeReal line =
    case String.tokens Char.isSpace line of
      ["const", n, "=", value] =>
        if (String.isSubstring "." value orelse String.isSubstring "e" value orelse String.isSubstring "E" value)
           andalso CharVector.all (fn c => Char.isDigit c orelse Char.contains ".eE+-" c) value
        then "const " ^ n ^ " = " ^ realG value else line
    | _ => line
end
