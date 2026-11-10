(* Sestoft's machine for Core (coreinterp_sig.sml): a control, which is an
   expression to evaluate in an environment, a cell to force, a value to
   return or an exception to raise, and a stack of frames, each step a
   transition from one state to the next in one loop. A cell is a value, a
   suspension, or a suspension under evaluation, a hole, which keeps its
   expression so that a raise can put it back. *)
structure CoreInterp : CORE_INTERP =
struct
  open Core

  datatype outcome = Exit of int | Raised of string * string | TooDeep | OutOfSteps

  exception Stuck of string

  datatype value =
      VCon of int * cell vector
    | VFun of (string * bool) list * exp * cell CoreMap.map     (* value parameters, each strict or not *)
    | VInt of int
    | VInteger of IntInf.int
    | VChar of int
    | VDouble of real
    | VStr of string
    | VWorld
    | VUTuple of cell vector
    | VExn of int * string
    | VRef of cell ref
  and state = Value of value | Thunk of exp * cell CoreMap.map | Hole of exp * cell CoreMap.map
  withtype cell = state ref

  type env = cell CoreMap.map

  datatype frame =
      Apply of cell list              (* arguments waiting for a function *)
    | Update of cell * exp * env      (* a cell under evaluation, and what it was *)
    | Alts of string * alt list * env (* a case waiting for its scrutinee *)
    | Catch of cell * cell            (* a handler, and the state token it is given *)

  datatype control =
      Eval of exp * env
    | Force of cell
    | Return of value
    | Throw of value
    | Halt of int

  fun stuck msg = raise Stuck msg

  (* ---- Exceptions ---- *)

  fun kindNumber name =
    let fun go (_, []) = stuck ("no kind of exception " ^ name)
          | go (i, k :: rest) = if k = name then i else go (i + 1, rest)
    in go (0, CorePrim.exnKinds) end
  fun exn (name, msg) = VExn (kindNumber name, msg)
  val nonTermination = exn ("NonTermination", "<<loop>>")

  (* ---- Primitives ---- *)

  val bool = fn b => VCon (if b then 1 else 0, Vector.fromList [])
  fun value (c : cell) =
    case !c of
      Value v => v
    | _ => stuck "a primitive is given a suspension where it wants a value"
  fun int c = case value c of VInt i => i | _ => stuck "a primitive is given what is not an Int"
  fun integer c = case value c of VInteger i => i | _ => stuck "a primitive is given what is not an Integer"
  fun char c = case value c of VChar i => i | _ => stuck "a primitive is given what is not a Char"
  fun double c = case value c of VDouble r => r | _ => stuck "a primitive is given what is not a Double"
  fun str c = case value c of VStr s => s | _ => stuck "a primitive is given what is not a Str"
  fun exnOf c = case value c of v as VExn _ => v | _ => stuck "a primitive is given what is not an Exn"
  fun refOf c = case value c of VRef r => r | _ => stuck "a primitive is given what is not a Ref"
  fun cell v : cell = ref (Value v)
  val world = VWorld

  (* the bytes of code point c in UTF-8 *)
  fun utf8 c =
    let
      fun b n = String.str (Char.chr n)
      fun cont (c, shift) = b (128 + IntInf.toInt (IntInf.andb (IntInf.~>> (IntInf.fromInt c, Word.fromInt shift), 63)))
    in
      if c < 128 then b c
      else if c < 2048 then b (192 + c div 64) ^ cont (c, 0)
      else if c < 65536 then b (224 + c div 4096) ^ cont (c, 6) ^ cont (c, 0)
      else b (240 + c div 262144) ^ cont (c, 12) ^ cont (c, 6) ^ cont (c, 0)
    end

  (* the text of a real as Mid's real_to_string gives it (format_real of
     runtime/prims.c): twelve significant digits, ~ for a minus, E for the
     exponent, and .0 where there is neither point nor exponent *)
  fun realText d =
    if Real.isNan d then "nan"
    else
      let val s = Real.fmt (StringCvt.GEN (SOME 12)) d
      in if CharVector.exists (fn c => c = #"." orelse c = #"E" orelse c = #"i") s then s else s ^ ".0" end

  (* a Double rounded to binary32, as Mid's real_to_single does: a Float
     is a Double that binary32 represents (D23) *)
  fun single r = Real32.toLarge (Real32.fromLarge IEEEReal.TO_NEAREST r)

  (* the elementary functions of Mid's real primitives: Math's, which are
     those primitives in Rune's Basis *)
  val elementary =
    [("sqrt", Math.sqrt), ("exp", Math.exp), ("log", Math.ln), ("sin", Math.sin), ("cos", Math.cos), ("tan", Math.tan),
     ("atan", Math.atan), ("sinh", Math.sinh), ("cosh", Math.cosh), ("tanh", Math.tanh)]

  (* a conversion to Int, as Mid's real_trunc and the others are: Domain for
     a NaN, Overflow past Int's range *)
  fun toInt (f : real -> int) r = if Real.isNan r then raise Domain else f r

  (* m and e of m * 2^e, m an integer of `bits` bits, or 0 and 0 for a zero:
     as real_frexp_man and real_frexp_exp give them, man in [0.5, 1) *)
  fun decode bits r =
    if Real.== (r, 0.0) then (0, 0)
    else
      let val {man, exp} = Real.toManExp r
      in (toInt Real.trunc (Real.fromManExp {man = man, exp = bits}), exp - bits) end

  (* ---- Handles ---- *)

  (* the files a program opened, by handle, from 3; 0 to 2 are standard
     input, output and error. What standard input has given and h_read has
     not yet, where it gave more than was asked for, waits in `pending`. *)
  datatype file = Reading of TextIO.instream | Writing of TextIO.outstream | Closed
  val files : (int * file) list ref = ref []
  fun fileOf h = Option.map #2 (List.find (fn (k, _) => k = h) (!files))
  val nextFile = ref 3
  val pending = ref ""
  val lastError = ref ""
  fun ioText e =
    case e of
      IO.Io {cause = OS.SysErr (msg, _), ...} => msg
    | IO.Io {cause, ...} => exnMessage cause
    | _ => exnMessage e

  (* the arithmetic of a type, by the name after its prefix *)
  fun arith (name, get, make, ops) args =
    case args of
      [a, b] =>
        (case List.find (fn (n, _) => n = name) ops of
           SOME (_, f) => Return (make (f (get a, get b)))
         | NONE => stuck ("no primitive " ^ name))
    | _ => stuck ("a primitive of two arguments is given " ^ Int.toString (length args))

  fun compare (get, lt, eq) (rel, args) =
    case args of
      [a, b] =>
        let val (x, y) = (get a, get b)
        in Return (bool (case rel of
                           "eq" => eq (x, y) | "ne" => not (eq (x, y)) | "lt" => lt (x, y)
                         | "le" => not (lt (y, x)) | "gt" => lt (y, x) | "ge" => not (lt (x, y))
                         | _ => stuck ("no comparison " ^ rel)))
        end
    | _ => stuck "a comparison of two arguments is given others"

  (* p's result on its argument cells, and the frames it pushes *)
  fun prim (p, args, out, err) : control * frame list =
    let
      fun only c = (c, [])
      fun under (prefix, rest) = String.isPrefix prefix p andalso (rest := String.extract (p, size prefix, NONE); true)
      val rest = ref ""
      val intOps = [("add", Int.+), ("sub", Int.-), ("mul", Int.* ), ("quot", Int.quot), ("rem", Int.rem),
                    ("div", Int.div), ("mod", Int.mod)]
      val integerOps = [("add", IntInf.+), ("sub", IntInf.-), ("mul", IntInf.* ), ("quot", IntInf.quot),
                        ("rem", IntInf.rem), ("div", IntInf.div), ("mod", IntInf.mod)]
      val doubleOps = [("add", Real.+), ("sub", Real.-), ("mul", Real.* ), ("div", Real./), ("atan2", Math.atan2)]
      val floatOps = List.map (fn (n, f) => (n, single o f)) doubleOps
      val cmp = ["eq", "ne", "lt", "le", "gt", "ge"]
      fun one args = case args of [a] => a | _ => stuck (p ^ " takes one argument")
      fun result () =
        case (p, args) of
          ("int_neg", _) => Return (VInt (Int.~ (int (one args))))
        | ("integer_neg", _) => Return (VInteger (IntInf.~ (integer (one args))))
        | ("double_neg", _) => Return (VDouble (Real.~ (double (one args))))
        | ("integer_from_int", _) => Return (VInteger (Int.toLarge (int (one args))))
        | ("integer_to_int", _) => Return (VInt (Int.fromLarge (integer (one args))))
        | ("char_ord", _) => Return (VInt (char (one args)))
        | ("char_chr", _) =>
            let val c = int (one args) in if c < 0 orelse c > 1114111 then Throw (exn ("Chr", "chr")) else Return (VChar c) end
        | ("double_from_int", _) => Return (VDouble (Real.fromInt (int (one args))))
        | ("double_to_str", _) => Return (VStr (realText (double (one args))))
        | ("str_size", _) => Return (VInt (size (str (one args))))
        | ("str_byte", [s, i]) => Return (VInt (Char.ord (String.sub (str s, int i))))
        | ("str_concat", [a, b]) => Return (VStr (str a ^ str b))
        | ("str_from_char", _) => Return (VStr (utf8 (char (one args))))
        | ("print_str", [s, _]) => (out (str s); Return world)
        | ("print_err", [s, _]) => (err (str s); Return world)
        | ("exit", [n, _]) => Halt (int n)
        | ("ref_new", [x, _]) => Return (VUTuple (Vector.fromList [cell world, cell (VRef (ref x))]))
        | ("ref_get", [r, _]) => Return (VUTuple (Vector.fromList [cell world, !(refOf r)]))
        | ("ref_set", [r, x, _]) => (refOf r := x; Return world)
        | ("real_world", []) => Return world
        | ("raise", _) => Throw (exnOf (one args))
        | ("raise_io", [e, _]) => Throw (exnOf e)
        | ("exn_error", _) => Return (exn ("ErrorCall", str (one args)))
        | ("exn_io", _) => Return (exn ("IOError", str (one args)))
        | ("exn_pattern", _) => Return (exn ("PatternMatchFail", str (one args)))
        | ("exn_kind", _) => (case exnOf (one args) of VExn (k, _) => Return (VInt k) | _ => stuck "exn_kind")
        | ("exn_name", _) => (case exnOf (one args) of VExn (k, _) => Return (VStr (List.nth (CorePrim.exnKinds, k)))
                                                     | _ => stuck "exn_name")
        | ("exn_message", _) => (case exnOf (one args) of VExn (_, m) => Return (VStr m) | _ => stuck "exn_message")
        | ("str_extract", [s, i, n]) => Return (VStr (String.substring (str s, int i, int n)))
        | ("float_neg", _) => Return (VDouble (Real.~ (double (one args))))
        | ("float_from_int", _) => Return (VDouble (single (Real.fromInt (int (one args)))))
        | ("float_from_double", _) => Return (VDouble (single (double (one args))))
        | ("float_to_double", _) => Return (VDouble (double (one args)))
        | ("float_to_str", _) => Return (VStr (realText (double (one args))))
        | ("h_open", [path, mode, _]) =>
            (let
              val f = case int mode of
                        0 => Reading (TextIO.openIn (str path))
                      | 1 => Writing (TextIO.openOut (str path))
                      | _ => Writing (TextIO.openAppend (str path))
              val h = !nextFile
            in
              nextFile := h + 1; files := (h, f) :: !files;
              Return (VUTuple (Vector.fromList [cell world, cell (VInt h)]))
            end
            handle e as IO.Io _ => (lastError := ioText e; Return (VUTuple (Vector.fromList [cell world, cell (VInt ~1)]))))
        | ("h_close", [h, _]) =>
            ((case fileOf (int h) of
                SOME (Reading i) => TextIO.closeIn i
              | SOME (Writing o') => TextIO.closeOut o'
              | _ => ());
             files := List.map (fn (k, f) => if k = int h then (k, Closed) else (k, f)) (!files);
             Return world)
        | ("h_read", [h, n, _]) =>
            (let
              val n = int n
              fun give s = Return (VUTuple (Vector.fromList [cell world, cell (VStr s)]))
              fun upTo s = if size s <= n then s else (pending := String.extract (s, n, NONE); String.substring (s, 0, n))
            in
              if n < 0 then raise Size
              else if n = 0 then give ""
              else
                case int h of
                  0 => if !pending <> "" then give (upTo (!pending before pending := "")) else give (upTo (TextIO.input TextIO.stdIn))
                | k => (case fileOf k of
                          SOME (Reading i) => give (TextIO.inputN (i, n))
                        | _ => give "")
            end
            handle IO.Io _ => Throw (exn ("IOError", "read failed")))
        | ("h_write", [h, s, _]) =>
            (let
              fun gave ok = Return (VUTuple (Vector.fromList [cell world, cell (bool ok)]))
            in
              case int h of
                1 => (out (str s); gave true)
              | 2 => (err (str s); gave true)
              | k => (case fileOf k of
                        SOME (Writing o') => (TextIO.output (o', str s); gave true)
                      | _ => (lastError := "Bad file descriptor"; gave false))
            end
            handle e as IO.Io _ => (lastError := ioText e; Return (VUTuple (Vector.fromList [cell world, cell (bool false)]))))
        | ("h_flush", [h, _]) =>
            ((case (int h, fileOf (int h)) of
                (1, _) => TextIO.flushOut TextIO.stdOut
              | (_, SOME (Writing o')) => TextIO.flushOut o'
              | _ => ());
             Return world)
        | ("h_error", [_]) => Return (VUTuple (Vector.fromList [cell world, cell (VStr (!lastError))]))
        | ("interleave", [action, _]) =>
            let
              val env = CoreMap.insert (CoreMap.insert (CoreMap.empty, "action", action), "w", cell world)
              val run = Case (App (Atom (Var "action"), [ValArg (Var "w")]), "r", [AltUTuple (["_", "x"], Atom (Var "x"))])
            in
              Return (VUTuple (Vector.fromList [cell world, ref (Thunk (run, env))]))
            end
        | _ =>
            if under ("int_", rest) then
              if List.exists (fn c => c = !rest) cmp then compare (int, Int.<, op =) (!rest, args)
              else arith (!rest, int, VInt, intOps) args
            else if under ("integer_", rest) then
              if List.exists (fn c => c = !rest) cmp then compare (integer, IntInf.<, op =) (!rest, args)
              else arith (!rest, integer, VInteger, integerOps) args
            else if under ("char_", rest) then compare (char, Int.<, op =) (!rest, args)
            else if under ("double_", rest) orelse under ("float_", rest) then
              let
                val round = if String.isPrefix "float_" p then single else (fn r => r)
                val bits = if String.isPrefix "float_" p then 24 else 53
                (* the least positive normal number of the type *)
                val normal = if String.isPrefix "float_" p then Real.fromManExp {man = 1.0, exp = ~126} else Real.minNormalPos
                fun test f = Return (bool (f (double (one args))))
              in
                if List.exists (fn c => c = !rest) cmp then compare (double, Real.<, Real.==) (!rest, args)
                else
                  case (!rest, List.find (fn (n, _) => n = !rest) elementary) of
                    (_, SOME (_, f)) => Return (VDouble (round (f (double (one args)))))
                  | ("truncate", _) => Return (VInt (toInt Real.trunc (double (one args))))
                  | ("round", _) => Return (VInt (toInt (Real.trunc o Real.realRound) (double (one args))))
                  | ("ceiling", _) => Return (VInt (toInt Real.ceil (double (one args))))
                  | ("floor", _) => Return (VInt (toInt Real.floor (double (one args))))
                  | ("is_nan", _) => test Real.isNan
                  | ("is_infinite", _) => test (fn r => not (Real.isNan r) andalso Real.isNan (r - r))
                  | ("is_negative_zero", _) => test (fn r => Real.== (r, 0.0) andalso Real.signBit r)
                  | ("is_denormalized", _) => test (fn r => not (Real.== (r, 0.0)) andalso Real.< (Real.abs r, normal))
                  | ("decode", _) =>
                      let val (m, e) = decode bits (double (one args))
                      in Return (VUTuple (Vector.fromList [cell (VInt m), cell (VInt e)])) end
                  | ("encode", _) =>
                      (case args of
                         [m, e] => Return (VDouble (round (Real.fromManExp {man = Real.fromInt (int m), exp = int e})))
                       | _ => stuck (p ^ " takes two arguments"))
                  | _ => arith (!rest, double, VDouble, if String.isPrefix "float_" p then floatOps else doubleOps) args
              end
            else stuck ("no primitive " ^ p ^ " of " ^ Int.toString (length args) ^ " arguments")
    in
      case (p, args) of
        ("catch", [action, handler, w]) => (Force action, [Apply [w], Catch (handler, w)])
      | _ => only (result ())
    end
    handle Overflow => (Throw (exn ("Overflow", "arithmetic overflow")), [])
         | Div => (Throw (exn ("Div", "divide by zero")), [])
         | Subscript => (Throw (exn ("Subscript", "index out of range")), [])
         | Size => (Throw (exn ("Subscript", "index out of range")), [])
         | Domain => (Throw (exn ("Domain", "domain")), [])

  (* ---- The machine ---- *)

  fun run {program, steps = limit, depth = most, out, err} =
    let
      (* the constructors' tags, by name *)
      val tags =
        List.foldl (fn (Data (_, _, cons), m) =>
                         #2 (List.foldl (fn ((c, _), (i, m)) => (i + 1, CoreMap.insert (m, c, i))) (0, m) cons)
                     | (_, m) => m)
                   CoreMap.empty (builtinData @ program)
      fun tagOf c = case CoreMap.find (tags, c) of SOME t => t | NONE => stuck ("no constructor " ^ c)
      fun lookup (env, x) = case CoreMap.find (env, x) of SOME c => c | NONE => stuck ("the variable " ^ x ^ " is not bound")
      fun litValue l =
        case l of
          LInt i => VInt (Int.fromLarge i)
        | LInteger i => VInteger i
        | LChar c => VChar c
        | LDouble s => VDouble (valOf (Real.fromString s))
        | LFloat s => VDouble (Real32.toLarge (valOf (Real32.fromString s)))
        | LStr s => VStr s
      fun atomCell env (Var x) = lookup (env, x)
        | atomCell _ (Lit l) = cell (litValue l)
      fun params bs = List.mapPartial (fn ValBinder (x, t) => SOME (x, isEval t) | TyBinder _ => NONE) bs
      fun bind (env, x, c) = if x = "_" then env else CoreMap.insert (env, x, c)
      (* what a let puts in its cell: a value where the expression is one *)
      fun alloc (e, env) : state =
        case e of
          Lam (bs, body) => (case params bs of [] => Thunk (e, env) | ps => Value (VFun (ps, body, env)))
        | Con (c, _, atoms) => Value (VCon (tagOf c, Vector.fromList (List.map (atomCell env) atoms)))
        | Atom (Lit l) => Value (litValue l)
        | _ => Thunk (e, env)

      (* the global environment: every value of the top level in scope of all *)
      val globals = List.foldl (fn (Val (x, _, _), env) => CoreMap.insert (env, x, ref (Value VWorld)) | (_, env) => env)
                               CoreMap.empty program
      val () = List.app (fn Val (x, _, e) => lookup (globals, x) := alloc (e, globals) | _ => ()) program
      val main = case CoreMap.find (globals, "main") of SOME c => c | NONE => stuck "the program has no main"

      fun matchAlt (v, alts, env) =
        let
          fun default [] = stuck "no alternative of a case matches its value"
            | default (AltDefault rhs :: _) = Eval (rhs, env)
            | default (_ :: rest) = default rest
          fun go [] = default alts
            | go (alt :: rest) =
                case (alt, v) of
                  (AltCon (c, xs, rhs), VCon (tag, fields)) =>
                    if tagOf c = tag then
                      Eval (rhs, ListPair.foldl (fn (x, f, env) => bind (env, x, f)) env (xs, Vector.foldr op :: [] fields))
                    else go rest
                | (AltLit (LInt i, rhs), VInt j) => if Int.toLarge j = i then Eval (rhs, env) else go rest
                | (AltLit (LChar i, rhs), VChar j) => if i = j then Eval (rhs, env) else go rest
                | (AltLit (LInteger i, rhs), VInteger j) => if i = j then Eval (rhs, env) else go rest
                | (AltUTuple (xs, rhs), VUTuple cs) =>
                    Eval (rhs, ListPair.foldl (fn (x, f, env) => bind (env, x, f)) env (xs, Vector.foldr op :: [] cs))
                | _ => go rest
        in go alts end

      (* the function v applied to the argument cells args *)
      fun applyFun (v, args, stack, depth) =
        case v of
          VFun (ps, body, env) =>
            let
              fun go (env, (x, strict) :: ps, c :: cs) =
                    (case (strict, !c) of
                       (true, Value _) => go (bind (env, x, c), ps, cs)
                     | (true, _) => stuck ("a suspension is given to the strict parameter " ^ x)
                     | _ => go (bind (env, x, c), ps, cs))
                | go (env, [], cs) =
                    (Eval (body, env), if null cs then stack else Apply cs :: stack, if null cs then depth else depth + 1)
                | go (env, ps, []) = (Return (VFun (ps, body, env)), stack, depth)
            in go (env, ps, args) end
        | _ => stuck "a value that is not a function is applied"

      fun loop (control, stack, depth, steps) =
        if depth > most then {outcome = TooDeep, steps = steps}
        else if (case limit of SOME n => steps >= n | NONE => false) then {outcome = OutOfSteps, steps = steps}
        else
          let val steps = steps + 1
          in
            case control of
              Halt n => {outcome = Exit n, steps = steps}
            | Eval (e, env) =>
                (case e of
                   Atom (Var x) => loop (Force (lookup (env, x)), stack, depth, steps)
                 | Atom (Lit l) => loop (Return (litValue l), stack, depth, steps)
                 | App (f, args) =>
                     (case List.mapPartial (fn ValArg a => SOME (atomCell env a) | TyArg _ => NONE) args of
                        [] => loop (Eval (f, env), stack, depth, steps)
                      | cells => loop (Eval (f, env), Apply cells :: stack, depth + 1, steps))
                 | Lam (bs, body) =>
                     (case params bs of
                        [] => loop (Eval (body, env), stack, depth, steps)
                      | ps => loop (Return (VFun (ps, body, env)), stack, depth, steps))
                 | Let (x, _, rhs, body) => loop (Eval (body, bind (env, x, ref (alloc (rhs, env)))), stack, depth, steps)
                 | LetRec (bs, body) =>
                     let
                       val cells = List.map (fn (x, _, _) => (x, ref (Value VWorld))) bs
                       val env' = List.foldl (fn ((x, c), env) => bind (env, x, c)) env cells
                       val () = ListPair.app (fn ((_, c), (_, _, rhs)) => c := alloc (rhs, env')) (cells, bs)
                     in loop (Eval (body, env'), stack, depth, steps) end
                 | Case (scrut, b, alts) => loop (Eval (scrut, env), Alts (b, alts, env) :: stack, depth + 1, steps)
                 | Con (c, _, atoms) =>
                     loop (Return (VCon (tagOf c, Vector.fromList (List.map (atomCell env) atoms))), stack, depth, steps)
                 | Prim (p, _, atoms) =>
                     let val (c, frames) = prim (p, List.map (atomCell env) atoms, out, err)
                     in loop (c, frames @ stack, depth + length frames, steps) end
                 | UTuple atoms => loop (Return (VUTuple (Vector.fromList (List.map (atomCell env) atoms))), stack, depth, steps)
                 | Cast (e, _) => loop (Eval (e, env), stack, depth, steps))
            | Force c =>
                (case !c of
                   Value v => loop (Return v, stack, depth, steps)
                 | Thunk (e, env) => (c := Hole (e, env); loop (Eval (e, env), Update (c, e, env) :: stack, depth + 1, steps))
                 | Hole _ => loop (Throw nonTermination, stack, depth, steps))
            | Return v =>
                (case stack of
                   [] => {outcome = Exit 0, steps = steps}
                 | Update (c, _, _) :: rest => (c := Value v; loop (Return v, rest, depth - 1, steps))
                 | Apply args :: rest =>
                     let val (control, stack, depth) = applyFun (v, args, rest, depth - 1)
                     in loop (control, stack, depth, steps) end
                 | Alts (b, alts, env) :: rest => loop (matchAlt (v, alts, bind (env, b, cell v)), rest, depth - 1, steps)
                 | Catch _ :: rest => loop (Return v, rest, depth - 1, steps))
            | Throw e =>
                (case stack of
                   [] => {outcome = case e of VExn (k, m) => Raised (List.nth (CorePrim.exnKinds, k), m)
                                            | _ => Raised ("?", ""),
                          steps = steps}
                 | Update (c, e', env) :: rest => (c := Thunk (e', env); loop (Throw e, rest, depth - 1, steps))
                 | Catch (handler, w) :: rest => loop (Force handler, Apply [cell e, w] :: rest, depth, steps)
                 | _ :: rest => loop (Throw e, rest, depth - 1, steps))
          end
    in
      files := []; nextFile := 3; pending := ""; lastError := "";
      loop (Force main, [Apply [cell world]], 1, 0)
    end
end
