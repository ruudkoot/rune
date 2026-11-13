(* Core to Mid (coretomid_sig.sml): Mid's text written from Core, in
   A-normal form by continuations. An expression is translated with what is
   to be done with its value, a continuation, which knows the Core type it
   wants and whether it may be copied into each branch (a return or a jump)
   or needs a join point. A variable of Core is held in Mid as its value, a
   suspension of it, a cell holding the suspension (in a letrec), or nothing
   (the state token). *)
structure CoreToMid : CORE_TO_MID =
struct
  open Core

  datatype fault = ThunkInSlot | ForceBehindCast | SuspTypeArg

  (* whether Core to Mid holds what it writes to its rules, which rhc sets
     at lint level 2; and what a breach of one is *)
  val checking = ref false
  exception Breach of string

  (* a type of Mid's text with susp at its head: a slot's, which no type
     argument is (D4: a type variable stands for a value; the lead's ruling
     of M28's last rule, which lives here, not in MidLint, since SML uses its
     polymorphic functions at T susp) *)
  fun isSuspType (t : string) : bool = String.isSuffix " susp" t orelse String.isSuffix " susp)" t

  exception Unsupported of string

  datatype abi = Function | Suspension | Literal

  (* ---- What is not lowered ---- *)

  (* a form of polymorphism Mid's types do not say, or Core to Mid does not
     yet: a function of a forall, a type after a value, a polymorphic value
     of a letrec or one that is no type lambda *)
  fun unlowered what = raise Unsupported (what ^ ": a form of polymorphism Core to Mid does not lower")

  (* ---- Bindings ---- *)

  datatype rep =
      Value of string      (* the value: a Mid atom *)
    | Lazy of string       (* a suspension of the value *)
    | Cell of string       (* a cell holding the suspension: a letrec's value, while the letrec is made *)
    | Erased               (* the state token *)
    | Partial of string * string list
                           (* a polymorphic function at its first types, the rest the binding's own *)

  (* a variable: how Mid holds it, its Core type, and how many type
     variables its Mid binding abstracts over *)
  type binding = {rep : rep, ty : ty, arity : int}

  type env = {vals : binding CoreMap.map, tyvars : string CoreMap.map}

  (* a newtype is erased, but one that reaches itself through newtypes,
     which System F cannot say (D2), is a box: a datatype of one
     constructor, whose field is the evaluated value it wraps *)
  datatype shape = DataT of (string * ty list) list | NewT of ty | BoxT of string * ty | Builtin
  type tycon = {name : string, params : (string * kind) list, shape : shape}

  (* what is done with a value: the Core type it is wanted at, whether the
     continuation may be copied into each branch, and the Mid it makes of an
     atom of that type *)
  type cont = {dup : bool, tail : bool, want : ty, k : string -> string}

  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun concat xs = String.concat xs
  fun commas xs = String.concatWith ", " xs

  (* the type arguments of a use, each a value's type: at lint level 2 one
     with susp at its head is a breach (M10b) *)
  fun typeArgs (use : string, ts : string list) : string =
    (if !checking then
       case List.find isSuspType ts of
         SOME t => raise Breach ("a use of " ^ use ^ " is given the type argument " ^ t
                                 ^ ", a suspension's, where a type variable stands for a value (D4)")
       | NONE => ()
     else ();
     "[" ^ commas ts ^ "]")

  fun isWorld t = case stripEval t of TCon "World" => true | _ => false
  fun isUnlifted t = case stripEval t of TCon "World" => true | TUTuple _ => true | _ => false

  (* ---- Precise types, as CoreLint works them out ---- *)

  fun sub (a, e) =
    case (a, e) of
      (TEval a', TEval e') => equalTy (a', e')
    | (TEval a', _) => subInner (a', e)
    | (_, TEval _) => false
    | _ => subInner (a, e)
  and subInner (a, e) =
    case (a, e) of
      (TUTuple xs, TUTuple ys) => length xs = length ys andalso ListPair.all sub (xs, ys)
    | (TFun (p, r), TFun (q, s)) => equalTy (p, q) andalso subInner (r, s)
    | _ => equalTy (a, e)

  fun relax t =
    case t of
      TEval u => relax u
    | TUTuple ts => TUTuple (List.map relax ts)
    | TFun (p, r) => TFun (p, relax r)
    | _ => t

  (* ---- What every program's Mid has ---- *)

  (* the globals of the prelude that have an identity, the exceptions of
     Core: in a program of units one unit makes them, the runtime's, and
     each other one's text declares them as the prelude does, its client
     reading them as imports (M21) *)
  val shared = ["grtErrorCall", "grtIOError", "grtPatternMatchFail", "grtNonTermination"]

  (* the exceptions of Core, each with its message, and the functions of
     the primitives that are no primitive of Mid: an exception's kind, name
     and message, a code point's character, and its bytes in UTF-8. The
     VM's built-in Loop, which ENTER raises of a suspension under evaluation
     (docs/bytecode.md), is NonTermination, <<loop>> (ruling 58) *)
  val prelude = String.concatWith "\n"
    ["(datatype option ('a) (0 \"NONE\") (1 \"SOME\" : 'a))",
     "(val grtErrorCall : exncon (return (newexn \"ErrorCall\")))",
     "(val grtIOError : exncon (return (newexn \"IOError\")))",
     "(val grtPatternMatchFail : exncon (return (newexn \"PatternMatchFail\")))",
     "(val grtNonTermination : exncon (return (newexn \"NonTermination\")))",
     "(funs",
     "  (fn grtExnKind ((vrtE : exn)) : int \"exn_kind\"",
     "    (let (vrtC : exncon) (exncon vrtE)",
     "    (let (vrt0 : bool) (prim ptr_eq vrtC grtErrorCall : (exncon * exncon) -> bool)",
     "    (if vrt0 (return 0)",
     "    (let (vrt1 : bool) (prim ptr_eq vrtC grtIOError : (exncon * exncon) -> bool)",
     "    (if vrt1 (return 1)",
     "    (let (vrt2 : bool) (prim ptr_eq vrtC grtPatternMatchFail : (exncon * exncon) -> bool)",
     "    (if vrt2 (return 2)",
     "    (let (vrt3 : bool) (prim ptr_eq vrtC grtNonTermination : (exncon * exncon) -> bool)",
     "    (if vrt3 (return 3)",
     "    (let (vrtN : string) (prim exn_name vrtE : exn -> string)",
     "    (let (vrtL : bool) (prim poly_eq vrtN \"Loop\" : (string * string) -> bool)",
     "    (if vrtL (return 3)",
     "    (let (vrt4 : bool) (prim poly_eq vrtN \"Div\" : (string * string) -> bool)",
     "    (if vrt4 (return 4)",
     "    (let (vrt5 : bool) (prim poly_eq vrtN \"Overflow\" : (string * string) -> bool)",
     "    (if vrt5 (return 5)",
     "    (let (vrt6 : bool) (prim poly_eq vrtN \"Subscript\" : (string * string) -> bool)",
     "    (if vrt6 (return 6)",
     "    (let (vrt7 : bool) (prim poly_eq vrtN \"Chr\" : (string * string) -> bool)",
     "    (if vrt7 (return 7)",
     "    (let (vrt8 : bool) (prim poly_eq vrtN \"Domain\" : (string * string) -> bool)",
     "    (if vrt8 (return 8) (return ~1))))))))))))))))))))))))",
     "  (fn grtExnName ((vrnE : exn)) : string \"exn_name\"",
     "    (let (vrnK : int) (app grtExnKind vrnE)",
     "    (let (vrn0 : bool) (prim poly_eq vrnK 0 : (int * int) -> bool) (if vrn0 (return \"ErrorCall\")",
     "    (let (vrn1 : bool) (prim poly_eq vrnK 1 : (int * int) -> bool) (if vrn1 (return \"IOError\")",
     "    (let (vrn2 : bool) (prim poly_eq vrnK 2 : (int * int) -> bool) (if vrn2 (return \"PatternMatchFail\")",
     "    (let (vrn3 : bool) (prim poly_eq vrnK 3 : (int * int) -> bool) (if vrn3 (return \"NonTermination\")",
     "    (let (vrn4 : bool) (prim poly_eq vrnK 4 : (int * int) -> bool) (if vrn4 (return \"Div\")",
     "    (let (vrn5 : bool) (prim poly_eq vrnK 5 : (int * int) -> bool) (if vrn5 (return \"Overflow\")",
     "    (let (vrn6 : bool) (prim poly_eq vrnK 6 : (int * int) -> bool) (if vrn6 (return \"Subscript\")",
     "    (let (vrn7 : bool) (prim poly_eq vrnK 7 : (int * int) -> bool) (if vrn7 (return \"Chr\")",
     "    (let (vrn8 : bool) (prim poly_eq vrnK 8 : (int * int) -> bool) (if vrn8 (return \"Domain\")",
     "    (return (prim exn_name vrnE : exn -> string))))))))))))))))))))))",
     "  (fn grtExnMessage ((vrmE : exn)) : string \"exn_message\"",
     "    (let (vrmK : int) (app grtExnKind vrmE)",
     "    (let (vrmS : bool) (prim int_lt vrmK 3 : (int * int) -> bool)",
     "    (let (vrmP : bool) (prim int_ge vrmK 0 : (int * int) -> bool)",
     "    (let (vrm1 : bool) (prim poly_eq vrmK 1 : (int * int) -> bool)",
     "    (if vrm1 (let (vrmI : (string * int * string * int)) (exnarg vrmE : (string * int * string * int)) (return (select 0 vrmI)))",
     "    (if vrmS (if vrmP (return (exnarg vrmE : string)) (return \"\"))",
     "    (let (vrm3 : bool) (prim poly_eq vrmK 3 : (int * int) -> bool) (if vrm3 (return \"<<loop>>\")",
     "    (let (vrm4 : bool) (prim poly_eq vrmK 4 : (int * int) -> bool) (if vrm4 (return \"divide by zero\")",
     "    (let (vrm5 : bool) (prim poly_eq vrmK 5 : (int * int) -> bool) (if vrm5 (return \"arithmetic overflow\")",
     "    (let (vrm6 : bool) (prim poly_eq vrmK 6 : (int * int) -> bool) (if vrm6 (return \"index out of range\")",
     "    (let (vrm7 : bool) (prim poly_eq vrmK 7 : (int * int) -> bool) (if vrm7 (return \"chr\")",
     "    (let (vrm8 : bool) (prim poly_eq vrmK 8 : (int * int) -> bool) (if vrm8 (return \"domain\")",
     "    (return \"\"))))))))))))))))))))",
     "  (fn grtChr ((vrcC : int)) : int \"chr\"",
     "    (let (vrcL : bool) (prim int_lt vrcC 0 : (int * int) -> bool)",
     "    (let (vrcH : bool) (prim int_gt vrcC 1114111 : (int * int) -> bool)",
     "    (if vrcL (let (vrcK : exncon) (builtinexn 6) (let (vrcE : exn) (mkexn vrcK ()) (raise vrcE)))",
     "    (if vrcH (let (vrcK2 : exncon) (builtinexn 6) (let (vrcE2 : exn) (mkexn vrcK2 ()) (raise vrcE2)))",
     "    (return vrcC))))))",
     "  (fn grtByte ((vrbN : int)) : string \"byte\"",
     "    (let (vrbC : char) (prim int_to_char vrbN : int -> char)",
     "    (return (prim string_from_char vrbC : char -> string))))",
     "  (fn grtLow ((vrlC : int) (vrlD : int)) : string \"utf8_continuation\"",
     "    (let (vrlQ : int) (prim int_div vrlC vrlD : (int * int) -> int)",
     "    (let (vrlM : int) (prim int_mod vrlQ 64 : (int * int) -> int)",
     "    (let (vrlB : int) (prim int_add vrlM 128 : (int * int) -> int)",
     "    (return (app grtByte vrlB))))))",
     "  (fn grtUtf8 ((vruC : int)) : string \"utf8\"",
     "    (let (vru1 : bool) (prim int_lt vruC 128 : (int * int) -> bool)",
     "    (if vru1 (return (app grtByte vruC))",
     "    (let (vruL : string) (app grtLow vruC 1)",
     "    (let (vru2 : bool) (prim int_lt vruC 2048 : (int * int) -> bool)",
     "    (if vru2",
     "      (let (vruQ : int) (prim int_div vruC 64 : (int * int) -> int)",
     "      (let (vruH : int) (prim int_add vruQ 192 : (int * int) -> int)",
     "      (let (vruB : string) (app grtByte vruH)",
     "      (return (prim string_concat vruB vruL : (string * string) -> string)))))",
     "    (let (vruM : string) (app grtLow vruC 64)",
     "    (let (vru3 : bool) (prim int_lt vruC 65536 : (int * int) -> bool)",
     "    (if vru3",
     "      (let (vruQ3 : int) (prim int_div vruC 4096 : (int * int) -> int)",
     "      (let (vruH3 : int) (prim int_add vruQ3 224 : (int * int) -> int)",
     "      (let (vruB3 : string) (app grtByte vruH3)",
     "      (let (vruT3 : string) (prim string_concat vruB3 vruM : (string * string) -> string)",
     "      (return (prim string_concat vruT3 vruL : (string * string) -> string))))))",
     "    (let (vruN : string) (app grtLow vruC 4096)",
     "    (let (vruQ4 : int) (prim int_div vruC 262144 : (int * int) -> int)",
     "    (let (vruH4 : int) (prim int_add vruQ4 240 : (int * int) -> int)",
     "    (let (vruB4 : string) (app grtByte vruH4)",
     "    (let (vruT4 : string) (prim string_concat vruB4 vruN : (string * string) -> string)",
     "    (let (vruU4 : string) (prim string_concat vruT4 vruM : (string * string) -> string)",
     "    (return (prim string_concat vruU4 vruL : (string * string) -> string)))))))))))))))))",
     "  (fn grtRead ((vhH : int) (vhN : int)) : string \"read\"",
     "    (handle vhX (return (prim file_read_vec vhH vhN : (int * int) -> string))",
     "      (let (vhI : (string * int * string * int)) (tuple \"read failed\" 8 \"\" vhH)",
     "      (let (vhE : exn) (mkexn grtIOError vhI) (raise vhE)))))",
     "  (fn grtEndText ((vetE : exn)) : string \"end_text\"",
     "    (let (vetM : string) (app grtExnMessage vetE)",
     "    (let (vetK : int) (app grtExnKind vetE)",
     "    (let (vetI : bool) (prim poly_eq vetK 1 : (int * int) -> bool)",
     "    (if vetI",
     "      (let (vetC : int) (app grtIoCode vetE)",
     "      (let (vetU : bool) (prim poly_eq vetC 0 : (int * int) -> bool)",
     "      (if vetU",
     "        (let (vetA : string) (prim string_concat \"user error (\" vetM : (string * string) -> string)",
     "        (return (prim string_concat vetA \")\" : (string * string) -> string)))",
     "        (return vetM))))",
     "      (return vetM))))))",
     "  (fn grtIoCode ((vicE : exn)) : int \"exn_io_code\"",
     "    (let (vicK : int) (app grtExnKind vicE)",
     "    (let (vicB : bool) (prim poly_eq vicK 1 : (int * int) -> bool)",
     "    (if vicB (let (vicI : (string * int * string * int)) (exnarg vicE : (string * int * string * int)) (return (select 1 vicI))) (return 0)))))",
     "  (fn grtIoFile ((vifE : exn)) : string \"exn_io_file\"",
     "    (let (vifK : int) (app grtExnKind vifE)",
     "    (let (vifB : bool) (prim poly_eq vifK 1 : (int * int) -> bool)",
     "    (if vifB (let (vifI : (string * int * string * int)) (exnarg vifE : (string * int * string * int)) (return (select 2 vifI))) (return \"\")))))",
     "  (fn grtIoHandle ((vihE : exn)) : int \"exn_io_handle\"",
     "    (let (vihK : int) (app grtExnKind vihE)",
     "    (let (vihB : bool) (prim poly_eq vihK 1 : (int * int) -> bool)",
     "    (if vihB (let (vihI : (string * int * string * int)) (exnarg vihE : (string * int * string * int)) (return (select 3 vihI))) (return ~1)))))",
     "  (fn grtIsInfinite ((viX : real)) : bool \"is_infinite\"",
     "    (let (viN : bool) (prim real_is_nan viX : real -> bool)",
     "    (if viN (return (con0 0 : bool))",
     "      (let (viD : real) (prim real_sub viX viX : (real * real) -> real)",
     "      (return (prim real_is_nan viD : real -> bool))))))",
     "  (fn grtIsNegativeZero ((vzX : real)) : bool \"is_negative_zero\"",
     "    (let (vzZ : bool) (prim real_eq vzX 0.0 : (real * real) -> bool)",
     "    (if vzZ (return (prim real_sign_bit vzX : real -> bool)) (return (con0 0 : bool)))))",
     "  (fn grtIsDenormal ((vdX : real) (vdN : real)) : bool \"is_denormalized\"",
     "    (let (vdZ : bool) (prim real_eq vdX 0.0 : (real * real) -> bool)",
     "    (if vdZ (return (con0 0 : bool))",
     "      (let (vdA : real) (prim real_abs vdX : real -> real)",
     "      (return (prim real_lt vdA vdN : (real * real) -> bool))))))",
     "  (fn grtDecode ((vcX : real) (vcB : int)) : (int * int) \"decode\"",
     "    (let (vcZ : bool) (prim real_eq vcX 0.0 : (real * real) -> bool)",
     "    (if vcZ (return (tuple 0 0))",
     "      (let (vcM : real) (prim real_frexp_man vcX : real -> real)",
     "      (let (vcE : int) (prim real_frexp_exp vcX : real -> int)",
     "      (let (vcS : real) (prim real_ldexp vcM vcB : (real * int) -> real)",
     "      (let (vcI : int) (prim real_trunc vcS : real -> int)",
     "      (let (vcF : int) (prim int_sub vcE vcB : (int * int) -> int)",
     "      (return (tuple vcI vcF))))))))))",
     "  (fn grtOpen ((voP : string) (voM : int)) : int \"open\"",
     "    (let (voO : int option) (prim file_open voP voM : (string * int) -> int option)",
     "    (case voO (0 (return ~1)) (1 (return (decon 1 voO : int option)))))))\n"]

  (* a program compiled whole (imports NONE), or a unit, each import bound
     as its interface says *)
  fun compile ({fault : fault option, imports : (string * abi) list option, makesShared : bool,
                newtypes : (string * bool) list}, prog : program)
              : {text : string, names : (string * string) list, abi : (string * abi) list, boxed : (string * bool) list} =
    let
      (* a whole program has no import *)
      val () =
        case (imports, List.find (fn Import _ => true | _ => false) prog) of
          (NONE, SOME (Import (x, _))) => raise Unsupported ("an import of another unit, " ^ x ^ ", in a program compiled whole")
        | _ => ()
      (* ---- The declarations ---- *)
      val decls = builtinData @ prog
      val tycons : tycon CoreMap.map ref = ref CoreMap.empty
      (* the newtypes the field of newtype t names, through newtypes *)
      val newtypeFields = List.mapPartial (fn Newtype (t, _, _, f) => SOME (t, f) | _ => NONE) decls
      fun namesIn t =
        case t of
          TCon c => [c]
        | TVar _ => []
        | TApp (f, a) => namesIn f @ namesIn a
        | TFun (a, b) => namesIn a @ namesIn b
        | TForall (_, _, b) => namesIn b
        | TEval a => namesIn a
        | TUTuple ts => List.concat (List.map namesIn ts)
      fun recursiveNewtype t =
        let
          fun reach (seen, []) = false
            | reach (seen, n :: rest) =
                if n = t then true
                else if member (n, seen) then reach (seen, rest)
                else case List.find (fn (m, _) => m = n) newtypeFields of
                       SOME (_, f) => reach (n :: seen, namesIn f @ rest)
                     | NONE => reach (n :: seen, rest)
        in
          case List.find (fn (m, _) => m = t) newtypeFields of
            SOME (_, f) => reach ([], namesIn f)
          | NONE => false
        end
      (* the newtypes given fewer arguments than their parameters somewhere,
         a type constructor of their own, which Mid can name only where the
         newtype is a datatype (M28: `int state` where m is State Int) *)
      val partialNewtypes =
        let
          val arity = List.mapPartial (fn Newtype (t, ps, _, _) => SOME (t, length ps) | _ => NONE) decls
          fun ty (t, acc) =
            case t of
              TFun (a, b) => ty (a, ty (b, acc))
            | TForall (_, _, b) => ty (b, acc)
            | TEval a => ty (a, acc)
            | TUTuple ts => List.foldl ty acc ts
            | _ =>
                let
                  val (head, args) = spine t
                  val acc = case head of
                              TCon c => (case List.find (fn (n, _) => n = c) arity of
                                           SOME (_, k) => if length args < k andalso not (member (c, acc)) then c :: acc else acc
                                         | NONE => acc)
                            | _ => acc
                in List.foldl ty acc args end
          fun atom (_, acc) = acc
          fun exp (e, acc) =
            case e of
              Atom _ => acc
            | App (f, args) => List.foldl (fn (TyArg t, acc) => ty (t, acc) | (_, acc) => acc) (exp (f, acc)) args
            | Lam (bs, b) => List.foldl (fn (ValBinder (_, t), acc) => ty (t, acc) | (_, acc) => acc) (exp (b, acc)) bs
            | Let (_, t, r, b) => ty (t, exp (r, exp (b, acc)))
            | LetRec (bs, b) => List.foldl (fn ((_, t, r), acc) => ty (t, exp (r, acc))) (exp (b, acc)) bs
            | Case (sc, _, alts) =>
                List.foldl (fn (AltCon (_, _, r), acc) => exp (r, acc) | (AltLit (_, r), acc) => exp (r, acc)
                             | (AltUTuple (_, r), acc) => exp (r, acc) | (AltDefault r, acc) => exp (r, acc))
                           (exp (sc, acc)) alts
            | Con (_, ts, _) => List.foldl ty acc ts
            | Prim (_, ts, _) => List.foldl ty acc ts
            | UTuple _ => acc
            | Cast (e, t) => ty (t, exp (e, acc))
        in
          List.foldl (fn (Data (_, _, cs), acc) => List.foldl (fn ((_, fs), acc) => List.foldl ty acc fs) acc cs
                       | (Newtype (_, _, _, f), acc) => ty (f, acc)
                       | (Val (_, t, e), acc) => ty (t, exp (e, acc))
                       | (Import (_, t), acc) => ty (t, acc))
                     [] decls
        end
      (* a newtype is a box where it reaches itself or is given fewer
         arguments than its parameters; one of another unit is as that unit
         made it, a fact of its interface (M21), and one it did not box is
         never given fewer here *)
      fun boxedNewtype t =
        case List.find (fn (n, _) => n = t) newtypes of
          SOME (_, b) => b
        | NONE => recursiveNewtype t orelse member (t, partialNewtypes)
      val () =
        List.app (fn (t, false) => if member (t, partialNewtypes)
                                   then raise Unsupported ("the newtype " ^ t ^ " of another unit, which that unit does not box, "
                                                           ^ "given fewer arguments than its parameters")
                                   else ()
                   | _ => ())
                 newtypes
      val usedNames : string list ref = ref []
      fun midName c =
        let
          val clean = String.translate (fn ch => if Char.isAlphaNum ch orelse ch = #"_" then String.str ch else "_") c
          val base = if clean <> "" andalso Char.isUpper (String.sub (clean, 0)) then clean else "T" ^ clean
          fun try n = let val m = if n = 0 then base else base ^ "_" ^ Int.toString n
                      in if member (m, !usedNames) then try (n + 1) else (usedNames := m :: !usedNames; m) end
        in try 0 end
      val () =
        List.app (fn Data ("Bool", [], cons) => tycons := CoreMap.insert (!tycons, "Bool", {name = "bool", params = [], shape = DataT cons})
                   | Data (t, ps, cons) => tycons := CoreMap.insert (!tycons, t, {name = midName t, params = ps, shape = DataT cons})
                   | Newtype (t, ps, c, field) =>
                       tycons := CoreMap.insert (!tycons, t, {name = if boxedNewtype t then midName t else t, params = ps,
                                                              shape = if boxedNewtype t then BoxT (c, field) else NewT field})
                   | Val _ => ()
                   | Import _ => ())
                 decls
      (* each constructor: its type, its tag, the types of its fields *)
      val cons : {tycon : string, tag : int, params : (string * kind) list, fields : ty list, count : int} CoreMap.map =
        List.foldl (fn (Data (t, ps, cs), m) =>
                         #2 (List.foldl (fn ((c, fs), (i, m)) =>
                                           (i + 1, CoreMap.insert (m, c, {tycon = t, tag = i, params = ps, fields = fs, count = length cs})))
                                        (0, m) cs)
                     | (_, m) => m)
                   CoreMap.empty decls
      fun conInfo c = case CoreMap.find (cons, c) of SOME i => i | NONE => raise Fail ("CoreToMid: no constructor " ^ c)
      fun tyconInfo c = CoreMap.find (!tycons, c)
      fun instFields (params : (string * kind) list, args, fields) =
        List.map (fn f => substTy (ListPair.map (fn ((a, _), t) => (a, t)) (params, args), f)) fields

      (* ---- Names ---- *)
      val counter = ref 0
      fun fresh prefix = (counter := !counter + 1; prefix ^ Int.toString (!counter))
      fun freshVar () = fresh "v"
      fun freshTyvar () = fresh "'t"
      fun quote s = "\"" ^ String.toString s ^ "\""

      (* ---- Types ---- *)

      (* the Mid type of a value of t *)
      fun valTy (env : env) (t : ty) : string =
        case stripEval t of
          TVar a => (case CoreMap.find (#tyvars env, a) of
                       SOME m => m
                     | NONE => raise Fail ("CoreToMid: the type variable " ^ a ^ " is not bound"))
        | TCon "Int" => "int"
        | TCon "Char" => "int"
        | TCon "Double" => "real"
        | TCon "Float" => "real"
        | TCon "Str" => "string"
        | TCon "Exn" => "exn"
        | TCon "World" => "unit"
        | TCon "Integer" => "IntInf.int"
        | TFun (p, r) => "(" ^ slotTy env p ^ " -> " ^ valTy env r ^ ")"
        | TUTuple ts =>
            (case List.filter (not o isWorld) ts of
               [] => "unit"
             | [c] => slotTy env c
             | cs => "(" ^ String.concatWith " * " (List.map (slotTy env) cs) ^ ")")
        | TForall _ => let val (ms, env', body) = forallOf (env, t) in "(forall [" ^ ms ^ "] " ^ valTy env' body ^ ")" end
        | t =>
            case spine t of
              (* `->` given fewer than two types, which Mid takes when its Ty
                 does (ruling 60, the lead's (a)); until then, refused *)
              (TCon "->", _) => raise Unsupported ("the function type's constructor, ->, given fewer than two types")
            | (TCon "Ref", [a]) => "(" ^ slotTy env a ^ " ref)"
            | (TCon "Arr", [a]) => "(" ^ slotTy env a ^ " array)"
            | (TCon c, args) =>
                (case tyconInfo c of
                   SOME {shape = NewT field, params, ...} => valTy env (hd (instFields (params, args, [field])))
                 | SOME {name, ...} =>
                     (case args of
                        [] => name
                      | [a] => "(" ^ valTy env a ^ ") " ^ name
                      | _ => "(" ^ commas (List.map (valTy env) args) ^ ") " ^ name)
                 | NONE => raise Fail ("CoreToMid: no type " ^ c))
            | (TVar m, args) =>
                (case args of
                   [a] => "(" ^ valTy env a ^ ") " ^ valTy env (TVar m)
                 | _ => "(" ^ commas (List.map (valTy env) args) ^ ") " ^ valTy env (TVar m))
            | _ => raise Fail ("CoreToMid: the type " ^ CoreText.showTy t)

      (* the variables a forall binds, named for Mid after their names in Core
         so that a type's text is one text, the environment that binds them,
         and the type under them *)
      and forallOf (env : env, t : ty) : string * env * ty =
        let
          fun go (TForall (a, _, b), env, ms) =
                let val m = "'q" ^ String.translate (fn ch => if Char.isAlphaNum ch orelse ch = #"_" then String.str ch else "_") a
                in go (b, {vals = #vals env, tyvars = CoreMap.insert (#tyvars env, a, m)}, m :: ms) end
            | go (b, env, ms) = (String.concatWith " " (List.rev ms), env, b)
        in go (stripEval t, env, []) end

      (* the Mid type of a slot of t: the value where t is evaluated or
         unlifted, a suspension of it where t is lazy; a lazy slot of a forall
         holds a suspension at every type, the forall outside *)
      and slotTy (env : env) (t : ty) : string =
        case t of
          TEval u => valTy env u
        | TForall _ => let val (ms, env', body) = forallOf (env, t) in "(forall [" ^ ms ^ "] " ^ slotTy env' body ^ ")" end
        | _ => if isUnlifted t then valTy env t else "(" ^ valTy env t ^ " susp)"

      (* the type a let gives what a slot of t holds: a forall's a scheme,
         the variables it binds the let's own *)
      fun bindTy (env : env) (t : ty) : string =
        case t of
          TForall _ => let val (ms, env', body) = forallOf (env, t) in "[" ^ ms ^ "] " ^ slotTy env' body end
        | TEval (TForall _) => let val (ms, env', body) = forallOf (env, t) in "[" ^ ms ^ "] " ^ valTy env' body end
        | _ => slotTy env t

      (* ---- Suspensions, form C's (M9) ---- *)

      (* make the suspension of the code fun (of type unit -> V) *)
      fun makeSusp (V, code) = "(prim thunk_make " ^ code ^ " : (unit -> " ^ V ^ ") -> (" ^ V ^ " susp))"
      fun forceSusp (V, s) =
        case fault of
          SOME ThunkInSlot => s
        | SOME ForceBehindCast => "(prim unsafe_cast " ^ s ^ " : (" ^ V ^ " susp) -> " ^ V ^ ")"
        | _ => "(prim thunk_force " ^ s ^ " : (" ^ V ^ " susp) -> " ^ V ^ ")"
      fun valueToSusp (V, a) = "(prim unsafe_cast " ^ a ^ " : " ^ V ^ " -> (" ^ V ^ " susp))"
      (* the code of a suspension: what it does first, and with its value *)
      fun thunkEntry body = "(let (" ^ freshVar () ^ " : unit) (prim thunk_blackhole () : unit -> unit) " ^ body ^ ")"
      fun thunkExit (V, a) = "(let (" ^ freshVar () ^ " : unit) (prim thunk_self_update " ^ a ^ " : " ^ V ^ " -> unit) (return " ^ a ^ "))"

      (* ---- Mid helpers ---- *)

      fun letv (ty, rhs, body : string -> string) =
        let val v = freshVar () in "(let (" ^ v ^ " : " ^ ty ^ ") " ^ rhs ^ " " ^ body v ^ ")" end

      (* the families of primitives a program names (CorePrimFamily), whose
         Mid text it has once *)
      val familiesUsed : string list ref = ref []

      (* Integer's literals, IntInf.int in Mid (M31, D20's D): each a global,
         made once, from an Int where it fits Mid's and otherwise from its
         sign and the bytes of its magnitude, the least significant first *)
      val integerLits : (IntInf.int * string) list ref = ref []
      fun integerGlobal i =
        case List.find (fn (j, _) => j = i) (!integerLits) of
          SOME (_, g) => g
        | NONE => let val g = fresh "gI" in integerLits := (i, g) :: !integerLits; g end
      fun integerDef (i, g) =
        let
          val bound = IntInf.pow (2, 62)
          fun bytes n = if n = 0 then [] else Char.chr (IntInf.toInt (IntInf.mod (n, 256))) :: bytes (IntInf.div (n, 256))
          val rhs =
            if IntInf.<= (IntInf.~ bound, i) andalso IntInf.< (i, bound) then
              "(prim intinf_from_int " ^ IntInf.toString i ^ " : int -> IntInf.int)"
            else
              "(prim intinf_make (con0 " ^ (if IntInf.< (i, 0) then "1" else "0") ^ " : bool) "
              ^ quote (String.implode (bytes (IntInf.abs i))) ^ " : (bool * string) -> IntInf.int)"
        in "(val " ^ g ^ " : IntInf.int (return " ^ rhs ^ "))\n" end

      fun constText l =
        case l of
          LInt i => IntInf.toString i
        | LChar c => Int.toString c
        | LDouble s => String.translate (fn #"-" => "~" | #"e" => "E" | #"+" => "" | c => String.str c) s
        | LFloat s => Real.fmt (StringCvt.SCI (SOME 16)) (Real32.toLarge (valOf (Real32.fromString s)))
        | LStr s => quote s
        | LInteger i => integerGlobal i

      fun raiseBuiltin k = letv ("exncon", "(builtinexn " ^ Int.toString k ^ ")", fn c =>
                             letv ("exn", "(mkexn " ^ c ^ " ())", fn e => "(raise " ^ e ^ ")"))

      (* ---- Environments ---- *)

      fun bindVal (env : env, x, b : binding) =
        if x = "_" then env else {vals = CoreMap.insert (#vals env, x, b), tyvars = #tyvars env}
      fun bindTyvar (env : env, a, m) = {vals = #vals env, tyvars = CoreMap.insert (#tyvars env, a, m)}
      fun lookup (env : env, x) =
        case CoreMap.find (#vals env, x) of
          SOME b => b
        | NONE => raise Fail ("CoreToMid: the variable " ^ x ^ " is not bound")
      (* the binding of a value of type t in a slot of type t held as atom a *)
      fun slotBinding (t, a) : binding =
        let fun foralls (TForall (_, _, b)) = 1 + foralls b | foralls _ = 0
        in {rep = if isWorld t then Erased else if isEval t orelse isUnlifted t then Value a else Lazy a, ty = t,
            arity = foralls (stripEval t)} end

      (* ---- The type of an expression, as CoreLint has it ---- *)

      fun litTy' l = TEval (litTy l)
      fun applyTy (f, args) =
        List.foldl (fn (TyArg t, f) => (case stripEval f of
                                          TForall (a, _, b) => substTy ([(a, t)], b)
                                        | _ => raise Fail "CoreToMid: a type argument to no forall")
                     | (ValArg _, f) => (case stripEval f of TFun (_, r) => r | _ => raise Fail "CoreToMid: no function"))
                   f args
      fun typeOf (env : env) (e : exp) : ty =
        case e of
          Atom (Var x) => #ty (lookup (env, x))
        | Atom (Lit l) => litTy' l
        | App (f, args) => applyTy (typeOf env f, args)
        | Lam (bs, body) =>
            let val env' = List.foldl (fn (TyBinder (a, _), env) => bindTyvar (env, a, "'?")
                                        | (ValBinder (x, t), env) => bindVal (env, x, {rep = Erased, ty = t, arity = 0}))
                                      env bs
            in lamTy (bs, stripEval (typeOf env' body)) end
        | Let (x, t, _, body) => stripEval (typeOf (bindVal (env, x, {rep = Erased, ty = t, arity = 0})) body)
        | LetRec (bs, body) =>
            stripEval (typeOf (List.foldl (fn ((x, t, _), env) => bindVal (env, x, {rep = Erased, ty = t, arity = 0})) env bs) body)
        | Case (scrut, b, alts) =>
            let
              val st = stripEval (typeOf env scrut)
              val env' = bindVal (env, b, {rep = Erased, ty = if isUnlifted st then st else TEval st, arity = 0})
              fun altTy (AltCon (c, xs, rhs)) =
                    let
                      val {params, fields, ...} = conInfo c
                      val args = #2 (spine st)
                      val fs = instFields (params, args, fields)
                    in typeOf (ListPair.foldl (fn (x, f, env) => bindVal (env, x, {rep = Erased, ty = f, arity = 0})) env' (xs, fs)) rhs end
                | altTy (AltUTuple (xs, rhs)) =
                    (case st of
                       TUTuple ts => typeOf (ListPair.foldl (fn (x, t, env) => bindVal (env, x, {rep = Erased, ty = t, arity = 0})) env' (xs, ts)) rhs
                     | _ => raise Fail "CoreToMid: an unboxed tuple's alternative")
                | altTy (AltLit (_, rhs)) = typeOf env' rhs
                | altTy (AltDefault rhs) = typeOf env' rhs
              val ts = List.map altTy alts
            in
              case ts of
                t :: rest => if List.all (fn u => sub (u, t)) rest then stripEval t else relax t
              | [] => raise Fail "CoreToMid: a case with no alternative"
            end
        | Con (c, tys, _) => apply (TCon (#tycon (conInfo c)), tys)
        | Prim (p, tys, atoms) =>
            (case CorePrim.find p of
               SOME {ty, ...} => applyTy (ty, List.map TyArg tys @ List.map ValArg atoms)
             | NONE => raise Fail ("CoreToMid: no primitive " ^ p))
        | UTuple atoms => TUTuple (List.map (fn Var x => #ty (lookup (env, x)) | Lit l => litTy' l) atoms)
        | Cast (_, t) => t

      (* ---- Atoms ---- *)

      (* the suspension a cell holds *)
      fun readCell (env, t, c, k) = letv (slotTy env (stripEval t), "(prim ref_get " ^ c ^ " : (" ^ slotTy env (stripEval t) ^ " ref) -> "
                                                                   ^ slotTy env (stripEval t) ^ ")", k)

      (* the value of atom a, evaluated, and its Core type *)
      fun atomValue (env : env, a : atom, k : string * ty -> string) : string =
        case a of
          Lit l => k (constText l, litTy' l)
        | Var x =>
            let val {rep, ty, arity} = lookup (env, x)
                val () = if arity > 0 then unlowered ("the polymorphic " ^ x ^ " used at no type") else ()
                val V = valTy env ty
            in
              case rep of
                Value v => k (v, ty)
              | Lazy s => letv (V, forceSusp (V, s), fn v => k (v, stripEval ty))
              | Cell c => readCell (env, ty, c, fn s => letv (V, forceSusp (V, s), fn v => k (v, stripEval ty)))
              | Erased => k ("()", ty)
              | Partial _ => unlowered ("the polymorphic " ^ x ^ " used at no type")
            end

      (* atom a in a slot of type p: its value where p is evaluated or
         unlifted, a suspension where p is lazy *)
      fun atomSlot (env : env, a : atom, p : ty, k : string -> string) : string =
        if isWorld p then k "()"
        else if (case (a, stripEval p) of (Var _, TForall _) => true | _ => false) then
          polySlot (env, case a of Var x => x | _ => "", p, k)
        else if isEval p orelse isUnlifted p then atomValue (env, a, fn (v, _) => k v)
        else
          let val V = valTy env p
          in
            case a of
              Lit l => letv (slotTy env p, valueToSusp (V, constText l), k)
            | Var x =>
                let val {rep, ty, arity} = lookup (env, x)
                    val () = if arity > 0 then unlowered ("the polymorphic " ^ x ^ " given as a value") else ()
                in
                  case rep of
                    Lazy s => k s
                  | Value v => letv (slotTy env p, valueToSusp (V, v), k)
                  | Cell c => readCell (env, ty, c, k)
                  | Erased => k "()"
                  | Partial _ => unlowered ("the polymorphic " ^ x ^ " given as a value")
                end
          end

      (* the polymorphic x in a slot of a forall: as it is where it is held
         as the slot holds it, and otherwise a suspension at every type of
         the slot's variables *)
      and polySlot (env : env, x : string, p : ty, k : string -> string) : string =
        let
          val {rep, arity, ...} = lookup (env, x)
          val (ms, env', body) = forallOf (env, p)
          val vars = String.tokens Char.isSpace ms
          fun at (v, pre) = v ^ typeArgs (x, pre @ vars)
          fun suspended inst =
            let val V = valTy env' body
            in letv ("[" ^ ms ^ "] (" ^ V ^ " susp)", valueToSusp (V, inst), k) end
        in
          if arity <> length vars then raise Unsupported ("the polymorphic " ^ x ^ " in a slot of another number of types")
          else
            case (isEval p, rep) of
              (true, Value v) => k v
            | (false, Lazy s) => k s
            | (false, Value v) => suspended (at (v, []))
            | (false, Partial (v, pre)) => suspended (at (v, pre))
            | _ => raise Unsupported ("the polymorphic " ^ x ^ " in a strict slot of " ^ CoreText.showTy p)
        end

      fun atomSlots (env, atoms, ps, k : string list -> string) =
        let
          fun go ([], [], acc) = k (List.rev acc)
            | go (a :: rest, p :: ps, acc) = atomSlot (env, a, p, fn s => go (rest, ps, s :: acc))
            | go _ = raise Fail "CoreToMid: atoms and their slots differ in number"
        in go (atoms, ps, []) end

      (* ---- Continuations ---- *)

      (* a continuation that returns what it is given, as it is (tail): a
         call given to it is a tail call, `(return (app ...))`, which Mid
         makes a tail call at every level, -O0 among them *)
      fun returning t : cont = {dup = true, tail = true, want = stripEval t, k = fn a => "(return " ^ a ^ ")"}

      (* a value of type from, where the continuation wants its type: an
         evaluated component of an unboxed tuple cast into its lazy slot *)
      fun deliver (env : env, c : cont, a : string, from : ty) : string =
        let val to = #want c
        in
          if valTy env from = valTy env to then #k c a
          else
            case (stripEval from, stripEval to) of
              (TUTuple fs, TUTuple ts) =>
                let
                  val pairs = List.filter (fn (f, _) => not (isWorld f)) (ListPair.zip (fs, ts))
                  fun comp (i, (f, t), k) =
                    let
                      fun conv x = if slotTy env f = slotTy env t then k x
                                   else letv (slotTy env t, valueToSusp (valTy env t, x), k)
                    in
                      if length pairs = 1 then conv a
                      else letv (slotTy env f, "(select " ^ Int.toString i ^ " " ^ a ^ ")", conv)
                    end
                  fun go (_, [], acc) =
                        (case List.rev acc of
                           [x] => #k c x
                         | xs => letv (valTy env to, "(tuple " ^ String.concatWith " " xs ^ ")", #k c))
                    | go (i, p :: rest, acc) = comp (i, p, fn x => go (i + 1, rest, x :: acc))
                in go (0, pairs, []) end
            | (TFun (p, r), TFun (_, r')) =>
                (* a function whose result is more evaluated than wanted, as
                   CoreLint lets it be: a function around it *)
                let
                  val w = freshVar ()
                  val x = freshVar ()
                  val body = letv (valTy env r, "(app " ^ a ^ " " ^ x ^ ")",
                                   fn y => deliver (env, returning r', y, r))
                in
                  "(fun (fn " ^ w ^ " ((" ^ x ^ " : " ^ slotTy env p ^ ")) : " ^ valTy env r' ^ " \"fn\" " ^ body ^ ") "
                  ^ #k c w ^ ")"
                end
            | _ => raise Fail ("CoreToMid: a value of " ^ valTy env from ^ " where " ^ valTy env to ^ " is wanted")
        end

      (* f, given a continuation it may copy into each branch *)
      fun branching (env : env, c : cont, f : cont -> string) : string =
        if #dup c then f c
        else
          let
            val j = fresh "j"
            val v = freshVar ()
          in
            "(join " ^ j ^ " ((" ^ v ^ " : " ^ valTy env (#want c) ^ ")) " ^ #k c v ^ " "
            ^ f {dup = true, tail = false, want = #want c, k = fn a => "(jump " ^ j ^ " " ^ a ^ ")"} ^ ")"
          end

      (* ---- Expressions ---- *)

      fun exp (env : env, e : exp, c : cont) : string =
        case e of
          Atom a => atomValue (env, a, fn (v, t) => deliver (env, c, v, t))
        | App (f, args) => app (env, f, args, c)
        | Lam (bs, body) =>
            let val (def, name) = fundef (env, NONE, "fn", bs, body, #want c)
            in "(fun " ^ def ^ " " ^ deliver (env, c, name, #want c) ^ ")" end
        | Let (x, t, rhs, body) => bind (env, x, t, rhs, fn env' => exp (env', body, c))
        | LetRec (bs, body) => bindRec (env, bs, fn env' => exp (env', body, c))
        | Case (scrut, b, alts) => caseOf (env, scrut, b, alts, c)
        | Con (k, tys, atoms) => con (env, k, tys, atoms, fn (a, t) => deliver (env, c, a, t))
        | Prim (p, tys, atoms) => prim (env, p, tys, atoms, c)
        | UTuple atoms =>
            (case #want c of
               TUTuple ws =>
                 let val kept = List.filter (fn (_, w) => not (isWorld w)) (ListPair.zip (atoms, ws))
                 in
                   atomSlots (env, List.map #1 kept, List.map #2 kept,
                              fn [] => #k c "()"
                               | [x] => #k c x
                               | xs => letv (valTy env (#want c), "(tuple " ^ String.concatWith " " xs ^ ")", #k c))
                 end
             | _ => raise Fail "CoreToMid: an unboxed tuple where none is wanted")
        | Cast (e, t) =>
            let
              val from = stripEval (typeOf env e)
              fun boxOf t = case spine t of
                              (TCon n, _) => (case tyconInfo n of SOME {shape = BoxT _, ...} => SOME n | _ => NONE)
                            | _ => NONE
            in
              case (boxOf from, boxOf t) of
                (NONE, SOME _) =>
                  (* into a box: the value, boxed *)
                  exp (env, e, {dup = false, tail = false, want = from,
                                k = fn v => letv (valTy env t, "(con 0 " ^ v ^ " : " ^ valTy env t ^ ")", fn b => deliver (env, c, b, t))})
              | (SOME _, NONE) =>
                  exp (env, e, {dup = false, tail = false, want = from,
                                k = fn v => letv (valTy env t, "(decon 0 " ^ v ^ " : " ^ valTy env from ^ ")", fn u => deliver (env, c, u, t))})
              | _ => exp (env, e, {dup = #dup c, tail = #tail c, want = from, k = #k c})
            end

      (* a function applied: its type arguments to its binding, its value
         arguments one at a time, each in its parameter's slot *)
      and app (env, f, args, c) =
        let
          fun tyArgs (TyArg t :: rest, acc) = tyArgs (rest, t :: acc)
            | tyArgs (rest, acc) = (List.rev acc, rest)
          val (tys, vals) = tyArgs (args, [])
          val vals = List.map (fn ValArg a => a | TyArg t => unlowered ("a type argument " ^ CoreText.showTy t
                                                                         ^ " after a value argument")) vals
          fun applyArgs (fv, fty, [], c) = deliver (env, c, fv, fty)
            | applyArgs (fv, fty, a :: rest, c) =
                (case stripEval fty of
                   TFun (p, r) =>
                     atomSlot (env, a, p, fn av =>
                       if null rest andalso #tail c andalso valTy env r = valTy env (#want c)
                       then "(return (app " ^ fv ^ " " ^ av ^ "))"
                       else letv (valTy env r, "(app " ^ fv ^ " " ^ av ^ ")", fn rv => applyArgs (rv, r, rest, c)))
                 | TForall _ => unlowered "a function polymorphic in a type after a value argument"
                 | t => raise Fail ("CoreToMid: " ^ CoreText.showTy t ^ " applied"))
        in
          case f of
            Atom (Var x) =>
              let val {rep, ty, arity} = lookup (env, x)
              in
                if arity > 0 then
                  if length tys <> arity then unlowered ("the polymorphic " ^ x ^ " at " ^ Int.toString (length tys)
                                                          ^ " of its " ^ Int.toString arity ^ " types")
                  else
                    let
                      (* rhc's mutant SuspTypeArg: the first a slot's type *)
                      val args = case (fault, tys) of
                                   (SOME SuspTypeArg, t :: ts) => slotTy env t :: List.map (valTy env) ts
                                 | _ => List.map (valTy env) tys
                      val inst = typeArgs (x, args)
                      val fty = applyTy (ty, List.map TyArg tys)
                      val V = valTy env fty
                    in
                      case rep of
                        Value v => applyArgs (v ^ inst, fty, vals, c)
                      | Lazy s => letv (V, forceSusp (V, s ^ inst), fn fv => applyArgs (fv, stripEval fty, vals, c))
                      | Partial (v, pre) => applyArgs (v ^ typeArgs (x, pre @ args), fty, vals, c)
                      | _ => raise Fail "CoreToMid: a polymorphic cell"
                    end
                else if not (null tys) then unlowered ("the type arguments of " ^ x ^ ", which Mid binds at no type")
                else atomValue (env, Var x, fn (fv, fty) => applyArgs (fv, fty, vals, c))
              end
          | Lam (TyBinder _ :: _, _) =>
              (* a type lambda applied where it is written, as M15 wraps a
                 primitive: bound to a name, as a let binds it, and that
                 name applied *)
              if null tys then raise Fail "CoreToMid: a type lambda applied to no type"
              else
                let val x = "lambda " ^ freshVar ()
                in polyBind (env, x, typeOf env f, f, fn env' => app (env', Atom (Var x), args, c)) end
          | _ =>
              if not (null tys) then unlowered "type arguments to an expression"
              else exp (env, f, {dup = false, tail = false, want = stripEval (typeOf env f),
                                 k = fn fv => applyArgs (fv, stripEval (typeOf env f), vals, c)})
        end

      (* the Mid function of a lambda of binders bs and body body, wanted at
         type want, named name (fresh where NONE) with label: its text and its
         name. Type binders come first, each a type variable of the function;
         a lambda of several value binders is curried, each function
         returning the next *)
      and fundef (env : env, name : string option, label : string, bs : binder list, body : exp, want : ty) : string * string =
        let
          val name = case name of SOME n => n | NONE => freshVar ()
          fun tyPrefix (TyBinder (a, _) :: rest, env, want, tvs) =
                (case stripEval want of
                   TForall (b, _, w) =>
                     let val m = freshTyvar ()
                     in tyPrefix (rest, bindTyvar (env, a, m), substTy ([(b, TVar a)], w), m :: tvs) end
                 | _ => raise Fail "CoreToMid: a type binder where no forall is wanted")
            | tyPrefix (rest, env, want, tvs) = (rest, env, want, List.rev tvs)
          val (bs, env', want', tvs) = tyPrefix (bs, env, stripEval want, [])
          val tyvars = if null tvs then "" else " [" ^ String.concatWith " " tvs ^ "]"
        in
          case bs of
            ValBinder (x, t) :: rest =>
              (case stripEval want' of
                 TFun (_, r) =>
                   let
                     val p = freshVar ()
                     val env'' = bindVal (env', x, slotBinding (t, p))
                     val text =
                       case rest of
                         [] => exp (env'', body, returning r)
                       | _ => let val (def, inner) = fundef (env'', NONE, label, rest, body, r)
                              in "(fun " ^ def ^ " (return " ^ inner ^ "))" end
                   in
                     ("(fn " ^ name ^ tyvars ^ " ((" ^ p ^ " : " ^ slotTy env'' t ^ ")) : " ^ valTy env'' r ^ " " ^ quote label
                      ^ " " ^ text ^ ")", name)
                   end
               | _ => raise Fail "CoreToMid: a value binder where no function is wanted")
          | TyBinder _ :: _ => unlowered "a lambda that binds a type after a value"
          | [] => raise Fail "CoreToMid: a lambda of type binders alone"
        end

      (* let x : t = rhs, then k in the environment with x *)
      and bind (env : env, x : string, t : ty, rhs : exp, k : env -> string) : string =
        case (t, rhs) of
          (TForall _, _) => polyBind (env, x, t, rhs, k)
        | (_, Lam (bs, body)) =>
            if List.exists (fn ValBinder _ => true | _ => false) bs then
              let val (def, name) = fundef (env, NONE, x, bs, body, t)
              in "(fun " ^ def ^ " " ^ k (bindVal (env, x, {rep = Value name, ty = t, arity = 0})) ^ ")" end
            else thunk (env, x, t, rhs, k)
        | (_, Atom (Var y)) => let val b = lookup (env, y) in k (bindVal (env, x, {rep = #rep b, ty = t, arity = #arity b})) end
        | (_, Atom (Lit l)) => k (bindVal (env, x, {rep = Value (constText l), ty = t, arity = 0}))
        | (_, Con (c, tys, atoms)) => con (env, c, tys, atoms, fn (a, _) => k (bindVal (env, x, {rep = Value a, ty = t, arity = 0})))
        | (_, Cast (e, _)) => if valTy env (typeOf env e) = valTy env t then bind (env, x, t, e, k) else thunk (env, x, t, rhs, k)
        | _ => thunk (env, x, t, rhs, k)

      (* a suspension of rhs, of type t, bound to x *)
      and thunk (env, x, t, rhs, k) =
        let
          val (def, code) = thunkCode (env, x, t, rhs, "")
          val V = valTy env t
          val s = freshVar ()
        in
          "(fun " ^ def ^ " (let (" ^ s ^ " : (" ^ V ^ " susp)) " ^ makeSusp (V, code) ^ " "
          ^ k (bindVal (env, x, {rep = Lazy s, ty = t, arity = 0})) ^ "))"
        end

      (* the code of a suspension of rhs, of type t: a function of unit *)
      and thunkCode (env, label, t, rhs, tyvars) : string * string =
        let
          val code = freshVar ()
          val V = valTy env t
          val body = thunkEntry (exp (env, rhs, {dup = true, tail = false, want = stripEval t, k = fn a => thunkExit (V, a)}))
        in ("(fn " ^ code ^ tyvars ^ " ((" ^ freshVar () ^ " : unit)) : " ^ V ^ " " ^ quote label ^ " " ^ body ^ ")", code) end

      (* a binding of a polymorphic type: a polymorphic function, or a
         polymorphic suspension, one at every type *)
      and polyBind (env, x, t, rhs, k) =
        case rhs of
          Atom (Var y) => let val b = lookup (env, y) in k (bindVal (env, x, {rep = #rep b, ty = t, arity = #arity b})) end
        | Lam (bs, body) =>
            let
              val tyBinders = List.length (List.filter (fn TyBinder _ => true | _ => false) bs)
              fun prefix (TyBinder _ :: rest) = 1 + prefix rest | prefix _ = 0
              val n = prefix bs
            in
              if List.exists (fn ValBinder _ => true | _ => false) bs then
                let val (def, name) = fundef (env, NONE, x, bs, body, t)
                in "(fun " ^ def ^ " " ^ k (bindVal (env, x, {rep = Value name, ty = t, arity = n})) ^ ")" end
              else if n <> tyBinders then raise Fail "CoreToMid: type binders apart"
              else
                let
                  (* a polymorphic suspension: its code abstracts the type variables *)
                  fun peel (TyBinder (a, _) :: rest, env, want, tvs) =
                        (case stripEval want of
                           TForall (b, _, w) => let val m = freshTyvar () in peel (rest, bindTyvar (env, a, m), substTy ([(b, TVar a)], w), m :: tvs) end
                         | _ => raise Fail "CoreToMid: no forall")
                    | peel (_, env, want, tvs) = (env, want, List.rev tvs)
                  val (env', t', tvs) = peel (bs, env, t, [])
                  val tyvars = " [" ^ String.concatWith " " tvs ^ "]"
                  val (def, code) = thunkCode (env', x, t', body, tyvars)
                  val V = valTy env' t'
                  val s = freshVar ()
                in
                  "(fun " ^ def ^ " (let (" ^ s ^ " :" ^ tyvars ^ " (" ^ V ^ " susp)) "
                  ^ makeSusp (V, code ^ "[" ^ commas tvs ^ "]") ^ " "
                  ^ k (bindVal (env, x, {rep = Lazy s, ty = t, arity = n})) ^ "))"
                end
            end
        | App (Atom (Var y), args) =>
            (* a polymorphic function at its first types: the name and those
               types, given the rest where it is used *)
            let
              val b = lookup (env, y)
              val tys = List.mapPartial (fn TyArg t => SOME t | ValArg _ => NONE) args
              val given = List.map (valTy env) tys
            in
              if length tys <> length args orelse length tys >= #arity b then
                unlowered ("the polymorphic " ^ x ^ ", bound to what is no type lambda")
              else
                case #rep b of
                  Value v => k (bindVal (env, x, {rep = Partial (v, given), ty = t, arity = #arity b - length tys}))
                | Partial (v, pre) => k (bindVal (env, x, {rep = Partial (v, pre @ given), ty = t, arity = #arity b - length tys}))
                | _ => unlowered ("the polymorphic " ^ x ^ ", a suspension at some of its types")
            end
        | _ => unlowered ("the polymorphic " ^ x ^ ", bound to what is no type lambda")

      (* a letrec: its functions one group, its values suspensions made
         through cells (D6's A), each cell set once all are made *)
      and bindRec (env, bs, k) =
        let
          fun isFun (_, _, Lam (bs, _)) = List.exists (fn ValBinder _ => true | _ => false) bs
            | isFun _ = false
          val funs = List.filter isFun bs
          val vals = List.filter (not o isFun) bs
          val names = List.map (fn (x, _, _) => (x, freshVar ())) funs
          fun funEnv env = ListPair.foldl (fn ((x, t, Lam (lbs, _)), (_, n), env) =>
                                             bindVal (env, x, {rep = Value n, ty = t,
                                                               arity = length (List.filter (fn TyBinder _ => true | _ => false) lbs)})
                                           | (_, _, env) => env)
                                          env (funs, names)
          fun group env =
            String.concatWith " " (ListPair.map (fn ((x, t, Lam (lbs, body)), (_, n)) => #1 (fundef (env, SOME n, x, lbs, body, t))
                                                  | _ => raise Fail "CoreToMid: no lambda")
                                                (funs, names))
          fun withFuns (env, rest) = if null funs then rest env else "(fun " ^ group env ^ " " ^ rest env ^ ")"
        in
          if null vals then withFuns (funEnv env, k)
          else
            let
              val () = List.app (fn (x, t, _) => case t of TForall _ => unlowered ("the polymorphic " ^ x ^ " of a letrec") | _ => ()) vals
              (* a cell for each value, holding a placeholder until it is set *)
              fun cells ([], env, acc) = finish (env, List.rev acc)
                | cells ((x, t, rhs) :: rest, env, acc) =
                    let val S = slotTy env t
                    in
                      letv (S, "(prim unsafe_cast () : unit -> " ^ S ^ ")", fn p =>
                        letv ("(" ^ S ^ " ref)", "(prim ref_new " ^ p ^ " : " ^ S ^ " -> (" ^ S ^ " ref))", fn c =>
                          cells (rest, bindVal (env, x, {rep = Cell c, ty = t, arity = 0}), (x, t, rhs, c) :: acc)))
                    end
              and finish (cellEnv, made) =
                let
                  val cellEnv = funEnv cellEnv
                  (* each value's suspension, made in the environment of cells *)
                  fun susps ([], acc) = sets (List.rev acc)
                    | susps ((x, t, rhs, c) :: rest, acc) =
                        let
                          val (def, code) = thunkCode (cellEnv, x, t, rhs, "")
                          val V = valTy cellEnv t
                          val s = freshVar ()
                        in
                          "(fun " ^ def ^ " (let (" ^ s ^ " : (" ^ V ^ " susp)) " ^ makeSusp (V, code) ^ " "
                          ^ susps (rest, (x, t, c, s) :: acc) ^ "))"
                        end
                  and sets made =
                    let
                      fun go [] = k (funEnv (List.foldl (fn ((x, t, _, s), env) => bindVal (env, x, {rep = Lazy s, ty = t, arity = 0}))
                                                        env made))
                        | go ((_, t, c, s) :: rest) =
                            let val S = slotTy cellEnv t
                            in letv ("unit", "(prim ref_set " ^ c ^ " " ^ s ^ " : ((" ^ S ^ " ref) * " ^ S ^ ") -> unit)", fn _ => go rest) end
                    in go made end
                in withFuns (cellEnv, fn _ => susps (made, [])) end
            in cells (vals, env, []) end
        end

      (* ---- Cases ---- *)

      and caseOf (env, scrut, b, alts, c) =
        let
          val st = stripEval (typeOf env scrut)
          val binderTy = if isUnlifted st then st else TEval st
        in
          exp (env, scrut, {dup = false, tail = false, want = st,
                            k = fn v => dispatch (bindVal (env, b, slotBinding (binderTy, v)), v, st, alts, c)})
        end

      and dispatch (env, v, st, alts, c) =
        let
          fun default () =
            case List.find (fn AltDefault _ => true | _ => false) alts of
              SOME (AltDefault rhs) => SOME rhs
            | _ => NONE
          fun bindFields (env, xs, fs, field : int -> (string -> string) -> string, k) =
            let
              fun go (_, [], [], env) = k env
                | go (i, x :: xs, f :: fs, env) =
                    if x = "_" orelse isWorld f then go (i + 1, xs, fs, env)
                    else field i (fn a => go (i + 1, xs, fs, bindVal (env, x, slotBinding (f, a))))
                | go _ = raise Fail "CoreToMid: binders and fields differ in number"
            in go (0, xs, fs, env) end
        in
          case st of
            TUTuple ts =>
              (case alts of
                 [AltUTuple (xs, rhs)] =>
                   let
                     val kept = List.filter (not o isWorld) ts
                     (* the position among the components Mid keeps *)
                     fun index i = length (List.filter (not o isWorld) (List.take (ts, i)))
                     fun field i k =
                       if isWorld (List.nth (ts, i)) then k "()"
                       else if length kept = 1 then k v
                       else letv (slotTy env (List.nth (ts, i)), "(select " ^ Int.toString (index i) ^ " " ^ v ^ ")", k)
                   in bindFields (env, xs, ts, field, fn env' => exp (env', rhs, c)) end
               | [AltDefault rhs] => exp (env, rhs, c)
               | _ => raise Fail "CoreToMid: the alternatives of an unboxed tuple")
          | _ =>
              case (spine st, alts) of
                ((TCon "Bool", []), _) =>
                  let
                    fun rhsOf name = case List.find (fn AltCon (k, _, _) => k = name | _ => false) alts of
                                       SOME (AltCon (_, _, rhs)) => rhs
                                     | _ => valOf (default ())
                  in branching (env, c, fn c => "(if " ^ v ^ " " ^ exp (env, rhsOf "True", c) ^ " " ^ exp (env, rhsOf "False", c) ^ ")") end
              | ((TCon tc, args), _) =>
                  (case tyconInfo tc of
                     SOME {shape = DataT cs, params, name} =>
                       let
                         val T = valTy env st
                         fun conBranch (env, k, xs, rhs, c) =
                           let
                             val {tag, fields, ...} = conInfo k
                             val fs = instFields (params, args, fields)
                             val n = length fs
                             fun withArg body =
                               case n of
                                 0 => body (fn _ => fn k => k "()")
                               | 1 => letv (bindTy env (hd fs), "(decon " ^ Int.toString tag ^ " " ^ v ^ " : " ^ T ^ ")",
                                            fn a => body (fn _ => fn k => k a))
                               | _ => letv ("(" ^ String.concatWith " * " (List.map (slotTy env) fs) ^ ")",
                                            "(decon " ^ Int.toString tag ^ " " ^ v ^ " : " ^ T ^ ")",
                                            fn p => body (fn i => fn k => letv (bindTy env (List.nth (fs, i)),
                                                                                  "(select " ^ Int.toString i ^ " " ^ p ^ ")", k)))
                           in
                             if List.all (fn x => x = "_") xs then exp (env, rhs, c)
                             else withArg (fn field => bindFields (env, xs, fs, field, fn env' => exp (env', rhs, c)))
                           end
                         val conAlts = List.mapPartial (fn AltCon (k, xs, rhs) => SOME (k, xs, rhs) | _ => NONE) alts
                         val exhaustive = length conAlts = length cs
                         (* the tag of a constructor of no field, written as
                            Mid's constant: its arm alone, since Lower, at
                            -O0, would take the constant apart in the others
                            too *)
                         val known = if String.isPrefix "(con0 " v then Int.fromString (String.extract (v, 6, NONE)) else NONE
                       in
                         case (cs, conAlts, known) of
                           ([_], [(k, xs, rhs)], _) => conBranch (env, k, xs, rhs, c)
                         | (_, [], _) => (case default () of SOME rhs => exp (env, rhs, c) | NONE => raise Fail "CoreToMid: no alternative")
                         | (_, _, SOME t) =>
                             (case List.find (fn (k, _, _) => #tag (conInfo k) = t) conAlts of
                                SOME (k, xs, rhs) => conBranch (env, k, xs, rhs, c)
                              | NONE => (case default () of SOME rhs => exp (env, rhs, c) | NONE => raiseBuiltin 0))
                         | _ =>
                             (* Mid's case on the tag (M29), whose switch Lower
                                makes: an arm a constructor, and the default
                                where the arms are not every constructor *)
                             branching (env, c, fn c =>
                               let
                                 val arms = List.map (fn (k, xs, rhs) => "(" ^ Int.toString (#tag (conInfo k)) ^ " "
                                                                          ^ conBranch (env, k, xs, rhs, c) ^ ")") conAlts
                                 val otherwise =
                                   if exhaustive then []
                                   else ["(else " ^ (case default () of SOME rhs => exp (env, rhs, c) | NONE => raiseBuiltin 0) ^ ")"]
                               in "(case " ^ v ^ " " ^ String.concatWith " " (arms @ otherwise) ^ ")" end)
                       end
                   | _ =>
                       (case (tc, List.filter (fn AltLit _ => true | _ => false) alts) of
                          (_, []) => (case default () of SOME rhs => exp (env, rhs, c) | NONE => raise Fail "CoreToMid: no alternative")
                        | (_, lits) =>
                            branching (env, c, fn c =>
                              let
                                val eqTy = if tc = "Integer" then "(IntInf.int * IntInf.int)" else "(int * int)"
                                fun chain [] = exp (env, valOf (default ()), c)
                                  | chain (AltLit (l, rhs) :: rest) =
                                      letv ("bool", "(prim poly_eq " ^ v ^ " " ^ constText l ^ " : " ^ eqTy ^ " -> bool)",
                                            fn bv => "(if " ^ bv ^ " " ^ exp (env, rhs, c) ^ " " ^ chain rest ^ ")")
                                  | chain (_ :: rest) = chain rest
                              in chain lits end)))
              | _ => (case default () of SOME rhs => exp (env, rhs, c) | NONE => raise Fail "CoreToMid: no alternative")
        end

      (* ---- Constructors ---- *)

      and con (env, k, tys, atoms, kk : string * ty -> string) : string =
        let
          val {tycon, tag, params, fields, ...} = conInfo k
          val t = apply (TCon tycon, tys)
          val T = valTy env t
          val fs = instFields (params, tys, fields)
        in
          atomSlots (env, atoms, fs,
                     fn [] => kk ("(con0 " ^ Int.toString tag ^ " : " ^ T ^ ")", t)
                      | [a] => letv (T, "(con " ^ Int.toString tag ^ " " ^ a ^ " : " ^ T ^ ")", fn v => kk (v, t))
                      | xs => letv ("(" ^ String.concatWith " * " (List.map (slotTy env) fs) ^ ")", "(tuple " ^ String.concatWith " " xs ^ ")",
                                    fn p => letv (T, "(con " ^ Int.toString tag ^ " " ^ p ^ " : " ^ T ^ ")", fn v => kk (v, t))))
        end

      (* ---- Primitives ---- *)

      and prim (env, p, tys, atoms, c) : string =
        let
          val {ty = pty, ...} = case CorePrim.find p of SOME x => x | NONE => raise Fail ("CoreToMid: no primitive " ^ p)
          val inst = List.foldl (fn (t, TForall (a, _, b)) => substTy ([(a, t)], b) | (_, t) => t) pty tys
          (* the parameters a primitive is given, as many as its atoms, and
             what it gives: a result of a function type, as `raise` at one,
             is no more parameters *)
          fun params (TFun (q, r), n) = if n = 0 then ([], TFun (q, r)) else let val (qs, res) = params (r, n - 1) in (q :: qs, res) end
            | params (t, _) = ([], t)
          val (ps, res) = params (inst, length atoms)
          fun out (rhsTy, rhs) = letv (rhsTy, rhs, fn r => deliver (env, c, r, res))
          (* a primitive of Mid of the arguments Core keeps, the state token's dropped *)
          fun kept xs = ListPair.foldr (fn (x, q, acc) => if isWorld q then acc else x :: acc) [] (xs, ps)
          fun argText xs = case kept xs of [] => "()" | ks => String.concatWith " " ks
          (* a primitive of Mid of the arguments Core keeps, the state token's dropped *)
          fun mid (name, ty) =
            atomSlots (env, atoms, ps, fn xs => out (valTy env res, "(prim " ^ name ^ " " ^ argText xs ^ " : " ^ ty ^ ")"))
          fun midAs (name, ty, resTy) =
            atomSlots (env, atoms, ps, fn xs =>
              letv (resTy, "(prim " ^ name ^ " " ^ argText xs ^ " : " ^ ty ^ ")", fn r => deliver (env, c, r, res)))
          fun call f = atomSlots (env, atoms, ps, fn xs => out (valTy env res, "(app " ^ f ^ " " ^ argText xs ^ ")"))
          (* a primitive of Mid whose real result is rounded to binary32 *)
          fun rounded (name, ty) =
            atomSlots (env, atoms, ps, fn xs =>
              letv ("real", "(prim " ^ name ^ " " ^ argText xs ^ " : " ^ ty ^ ")", fn r =>
                out ("real", "(prim real_to_single " ^ r ^ " : real -> real)")))
          fun notOf (name, ty) =
            atomSlots (env, atoms, ps, fn xs =>
              letv ("bool", "(prim " ^ name ^ " " ^ String.concatWith " " xs ^ " : " ^ ty ^ ")", fn b =>
                branching (env, c, fn c => "(if " ^ b ^ " " ^ deliver (env, c, "(con0 0 : bool)", res) ^ " "
                                           ^ deliver (env, c, "(con0 1 : bool)", res) ^ ")")))
          val i2 = "(int * int)"
          val n2 = "(IntInf.int * IntInf.int)"
          val r2 = "(real * real)"
          fun suffix s = String.extract (p, size s, NONE)
          val S = case tys of [a] => slotTy env a | _ => ""
        in
          case p of
            "int_neg" => mid ("int_neg", "int -> int")
          | "int_eq" => mid ("poly_eq", i2 ^ " -> bool")
          | "int_ne" => notOf ("poly_eq", i2 ^ " -> bool")
          | "char_eq" => mid ("poly_eq", i2 ^ " -> bool")
          | "integer_eq" => mid ("poly_eq", n2 ^ " -> bool")
          | "integer_ne" => notOf ("poly_eq", n2 ^ " -> bool")
          | "integer_neg" => mid ("intinf_neg", "IntInf.int -> IntInf.int")
          | "integer_from_int" => mid ("intinf_from_int", "int -> IntInf.int")
          | "integer_to_int" => mid ("intinf_to_int", "IntInf.int -> int")
          | "char_ne" => notOf ("poly_eq", i2 ^ " -> bool")
          | "char_ord" => atomSlots (env, atoms, ps, fn [x] => deliver (env, c, x, res) | _ => raise Fail "char_ord")
          | "char_chr" => call "grtChr"
          | "double_neg" => mid ("real_neg", "real -> real")
          | "double_eq" => mid ("real_eq", r2 ^ " -> bool")
          | "double_ne" => notOf ("real_eq", r2 ^ " -> bool")
          | "double_from_int" => mid ("int_to_real", "int -> real")
          | "double_to_str" => mid ("real_to_string", "real -> string")
          | "float_to_str" => mid ("real_to_string", "real -> string")
          | "float_neg" => mid ("real_neg", "real -> real")
          | "float_from_int" => rounded ("int_to_real", "int -> real")
          | "float_from_double" => mid ("real_to_single", "real -> real")
          | "float_to_double" => atomSlots (env, atoms, ps, fn [x] => deliver (env, c, x, res) | _ => raise Fail "float_to_double")
          | "str_extract" => mid ("string_extract", "(string * int * int) -> string")
          | "h_open" => call "grtOpen"
          | "h_close" => midAs ("file_close", "int -> unit", "unit")
          | "h_read" => call "grtRead"
          | "h_write" => mid ("file_write", "(int * string) -> bool")
          | "h_flush" => midAs ("file_flush", "int -> unit", "unit")
          | "h_error" => mid ("file_error", "unit -> string")
          | "interleave" =>
              (* a lazy let of the action run with a state of its own, so
                 that its suspension is the form's, as any other *)
              (case (tys, atoms) of
                 ([a], [act, w]) =>
                   let
                     val r = "rhc'interleaved"
                     val w' = "rhc'world"
                     val run = Case (Prim ("real_world", [], []), w',
                                     [AltDefault (Case (App (Atom act, [ValArg (Var w')]), "rhc'result",
                                                        [AltUTuple (["_", "rhc'value"], Atom (Var "rhc'value"))]))])
                   in exp (env, Let (r, a, run, UTuple [w, Var r]), c) end
               | _ => raise Fail "interleave")
          | "str_size" => mid ("string_size", "string -> int")
          | "str_byte" =>
              atomSlots (env, atoms, ps, fn xs =>
                letv ("char", "(prim string_sub " ^ String.concatWith " " xs ^ " : (string * int) -> char)", fn ch =>
                  out ("int", "(prim char_ord " ^ ch ^ " : char -> int)")))
          | "str_concat" => mid ("string_concat", "(string * string) -> string")
          | "str_from_char" => call "grtUtf8"
          | "print_str" => midAs ("print", "string -> unit", "unit")
          | "print_err" => midAs ("print_err", "string -> unit", "unit")
          | "exit" => midAs ("exit", "int -> unit", "unit")
          | "ref_new" => midAs ("ref_new", S ^ " -> (" ^ S ^ " ref)", "(" ^ S ^ " ref)")
          | "ref_get" => midAs ("ref_get", "(" ^ S ^ " ref) -> " ^ S, S)
          | "ref_set" => midAs ("ref_set", "((" ^ S ^ " ref) * " ^ S ^ ") -> unit", "unit")
          | "real_world" => deliver (env, c, "()", res)
          | "raise" => atomSlots (env, atoms, ps, fn [e] => "(raise " ^ e ^ ")" | _ => raise Fail "raise")
          | "raise_io" => atomSlots (env, atoms, ps, fn (e :: _) => "(raise " ^ e ^ ")" | _ => raise Fail "raise_io")
          | "exn_error" => atomSlots (env, atoms, ps, fn [s] => out ("exn", "(mkexn grtErrorCall " ^ s ^ ")") | _ => raise Fail "exn_error")
          | "exn_io" =>
              atomSlots (env, atoms, ps, fn [s] =>
                letv ("(string * int * string * int)", "(tuple " ^ s ^ " 0 \"\" ~1)", fn t => out ("exn", "(mkexn grtIOError " ^ t ^ ")"))
                | _ => raise Fail "exn_io")
          | "exn_io_full" =>
              atomSlots (env, atoms, ps, fn [code, text, file, h] =>
                letv ("(string * int * string * int)", "(tuple " ^ text ^ " " ^ code ^ " " ^ file ^ " " ^ h ^ ")", fn t =>
                  out ("exn", "(mkexn grtIOError " ^ t ^ ")"))
                | _ => raise Fail "exn_io_full")
          | "exn_io_code" => call "grtIoCode"
          | "exn_io_file" => call "grtIoFile"
          | "exn_io_handle" => call "grtIoHandle"
          | "str_eq" => mid ("string_eq", "(string * string) -> bool")
          | "double_pow" => mid ("real_pow", "(real * real) -> real")
          | "arr_new" => midAs ("array_new", "(int * " ^ S ^ ") -> (" ^ S ^ " array)", "(" ^ S ^ " array)")
          | "arr_set" => midAs ("array_update", "((" ^ S ^ " array) * int * " ^ S ^ ") -> unit", "unit")
          | "arr_read" => midAs ("array_sub", "((" ^ S ^ " array) * int) -> " ^ S, S)
          | "arr_size" => mid ("array_length", "(" ^ S ^ " array) -> int")
          | "arr_get" =>
              (* the cell's suspension, forced: a primitive gives a value *)
              atomSlots (env, atoms, ps, fn xs =>
                letv (S, "(prim array_sub " ^ argText xs ^ " : ((" ^ S ^ " array) * int) -> " ^ S ^ ")", fn sv =>
                  letv (valTy env res, forceSusp (valTy env res, sv), fn v => deliver (env, c, v, res))))
          | "exn_pattern" => atomSlots (env, atoms, ps, fn [s] => out ("exn", "(mkexn grtPatternMatchFail " ^ s ^ ")") | _ => raise Fail "exn_pattern")
          | "exn_kind" => call "grtExnKind"
          | "exn_name" => call "grtExnName"
          | "exn_message" => call "grtExnMessage"
          | "catch" =>
              (case (tys, atoms) of
                 ([a], [act, h, _]) =>
                   let
                     val R = slotTy env a
                     val actTy = "(unit -> " ^ R ^ ")"
                   in
                     atomSlot (env, act, List.nth (ps, 0), fn sAct =>
                       atomSlot (env, h, List.nth (ps, 1), fn sH =>
                         branching (env, c, fn c =>
                           let val x = freshVar ()
                           in
                             "(handle " ^ x ^ " "
                             ^ letv (actTy, forceSusp (actTy, sAct), fn f => letv (R, "(app " ^ f ^ " ())", fn r => deliver (env, c, r, res)))
                             ^ " "
                             ^ letv ("(exn -> " ^ actTy ^ ")", forceSusp ("(exn -> " ^ actTy ^ ")", sH), fn g =>
                                 letv (actTy, "(app " ^ g ^ " " ^ x ^ ")", fn f => letv (R, "(app " ^ f ^ " ())", fn r => deliver (env, c, r, res))))
                             ^ ")"
                           end)))
                   end
               | _ => raise Fail "catch")
          | _ =>
              if String.isPrefix "integer_" p then
                let val op' = suffix "integer_"
                in
                  if member (op', ["lt", "le", "gt", "ge"]) then mid ("intinf_" ^ op', n2 ^ " -> bool")
                  else mid ("intinf_" ^ op', n2 ^ " -> IntInf.int")
                end
              else if String.isPrefix "int_" p orelse String.isPrefix "char_" p then
                let val op' = if String.isPrefix "int_" p then suffix "int_" else suffix "char_"
                in
                  if member (op', ["lt", "le", "gt", "ge"]) then mid ("int_" ^ op', i2 ^ " -> bool")
                  else mid ("int_" ^ op', i2 ^ " -> int")
                end
              else if String.isPrefix "double_" p orelse String.isPrefix "float_" p then
                let
                  val float = String.isPrefix "float_" p
                  val op' = if float then suffix "float_" else suffix "double_"
                  (* the result of Mid's primitive, rounded where the type is Float *)
                  fun real (name, ty) = if float then rounded (name, ty) else mid (name, ty)
                  val elementary = ["sqrt", "exp", "sin", "cos", "tan", "atan", "sinh", "cosh", "tanh"]
                in
                  if member (op', ["lt", "le", "gt", "ge"]) then mid ("real_" ^ op', r2 ^ " -> bool")
                  else if op' = "eq" then mid ("real_eq", r2 ^ " -> bool")
                  else if op' = "ne" then notOf ("real_eq", r2 ^ " -> bool")
                  else if member (op', elementary) then real ("real_" ^ op', "real -> real")
                  else
                    case op' of
                      "log" => real ("real_ln", "real -> real")
                    | "truncate" => mid ("real_trunc", "real -> int")
                    | "floor" => mid ("real_floor", "real -> int")
                    | "ceiling" => mid ("real_ceil", "real -> int")
                    | "round" =>
                        atomSlots (env, atoms, ps, fn xs =>
                          letv ("real", "(prim real_round_r " ^ argText xs ^ " : real -> real)", fn r =>
                            out ("int", "(prim real_trunc " ^ r ^ " : real -> int)")))
                    | "is_nan" => mid ("real_is_nan", "real -> bool")
                    | "is_infinite" => call "grtIsInfinite"
                    | "is_negative_zero" => call "grtIsNegativeZero"
                    | "is_denormalized" =>
                        atomSlots (env, atoms, ps, fn xs =>
                          out ("bool", "(app grtIsDenormal " ^ argText xs ^ " "
                                       ^ (if float then "1.1754943508222875E~38" else "2.2250738585072014E~308") ^ ")"))
                    | "decode" => atomSlots (env, atoms, ps, fn xs =>
                                    out ("(int * int)", "(app grtDecode " ^ argText xs ^ " " ^ (if float then "24" else "53") ^ ")"))
                    | "encode" =>
                        atomSlots (env, atoms, ps, fn xs =>
                          case xs of
                            [m, e] =>
                              letv ("real", "(prim int_to_real " ^ m ^ " : int -> real)", fn r =>
                                if float then
                                  letv ("real", "(prim real_ldexp " ^ r ^ " " ^ e ^ " : (real * int) -> real)", fn x =>
                                    out ("real", "(prim real_to_single " ^ x ^ " : real -> real)"))
                                else out ("real", "(prim real_ldexp " ^ r ^ " " ^ e ^ " : (real * int) -> real)"))
                          | _ => raise Fail "encode")
                    | _ => real ("real_" ^ op', r2 ^ " -> real")
                end
              else
                case CorePrim.familyOf p of
                  SOME ({name = fam, ...}, {mid = f, ...}) =>
                    ((if member (fam, !familiesUsed) then () else familiesUsed := fam :: !familiesUsed); call f)
                | NONE => raise Fail ("CoreToMid: no lowering of the primitive " ^ p)
        end


      (* ---- The program ---- *)

      val empty : env = {vals = CoreMap.empty, tyvars = CoreMap.empty}
      fun leadingForalls (TForall (_, _, b)) = 1 + leadingForalls b
        | leadingForalls _ = 0
      fun isFunction (Lam (bs, _)) = List.exists (fn ValBinder _ => true | _ => false) bs
        | isFunction _ = false
      fun isLiteral (Atom (Lit _)) = true
        | isLiteral _ = false

      val vals = List.mapPartial (fn Val v => SOME v | _ => NONE) prog
      val globals = List.map (fn (x, t, e) => (x, t, e, fresh "g")) vals
      (* each import of another unit, a global of the text, as its unit made
         it *)
      fun abiOf x =
        case List.find (fn (n, _) => n = x) (getOpt (imports, [])) of
          SOME (_, a) => a
        | NONE => raise Unsupported ("an import whose making no interface gives: " ^ x)
      val importGlobals =
        List.mapPartial (fn Import (x, t) => SOME (x, t, fresh "g", abiOf x) | _ => NONE) prog
      val genv =
        List.foldl (fn ((x, t, e, g), env) =>
                      bindVal (env, x, {rep = if isFunction e then Value g
                                              else case e of Atom (Lit l) => Value (constText l) | _ => Lazy g,
                                        ty = t, arity = leadingForalls t}))
                   empty globals
      val genv =
        List.foldl (fn ((x, t, g, a), env) =>
                      bindVal (env, x, {rep = case a of Suspension => Lazy g | _ => Value g, ty = t, arity = leadingForalls t}))
                   genv importGlobals
      (* an import declared at its scheme, the exporter's: its type under
         its leading foralls, a suspension's in its susp; the expression a
         placeholder the client drops *)
      fun importText (_, t, g, a) =
        let
          fun peel (t, env, tvs) =
            case stripEval t of
              TForall (b, _, w) => let val m = freshTyvar () in peel (w, bindTyvar (env, b, m), m :: tvs) end
            | t' => (env, t', List.rev tvs)
          val (env, body, tvs) = peel (t, genv, [])
          val V = valTy env body
          val scheme = (if null tvs then "" else "[" ^ String.concatWith " " tvs ^ "] ")
                       ^ (case a of Suspension => "(" ^ V ^ " susp)" | _ => V)
        in "(val " ^ g ^ " : " ^ scheme ^ " (return ()))\n" end

      (* the datatypes, each with its type variables *)
      fun datatypeText (t, ps, cs) =
        let
          val tvs = List.map (fn _ => freshTyvar ()) ps
          val env = ListPair.foldl (fn ((a, _), m, env) => bindTyvar (env, a, m)) empty (ps, tvs)
          val name = #name (valOf (tyconInfo t))
          fun conText (i, (c, fields)) =
            "(" ^ Int.toString i ^ " " ^ quote c
            ^ (case fields of
                 [] => ""
               | _ => " : " ^ String.concatWith " * " (List.map (slotTy env) fields)) ^ ")"
        in
          "(datatype " ^ name ^ " (" ^ String.concatWith " " tvs ^ ") "
          ^ String.concatWith " " (ListPair.map conText (List.tabulate (length cs, fn i => i), cs)) ^ ")\n"
        end
      val datatypes =
        List.mapPartial (fn Data (t, ps, cs) => SOME (datatypeText (t, ps, cs))
                          | Newtype (t, ps, c, field) =>
                              if boxedNewtype t then
                                let
                                  val tvs = List.map (fn _ => freshTyvar ()) ps
                                  val env = ListPair.foldl (fn ((a, _), m, env) => bindTyvar (env, a, m)) empty (ps, tvs)
                                in
                                  SOME ("(datatype " ^ #name (valOf (tyconInfo t)) ^ " (" ^ String.concatWith " " tvs ^ ") (0 "
                                        ^ quote c ^ " : " ^ valTy env field ^ "))\n")
                                end
                              else NONE
                          | _ => NONE)
                        prog

      (* the functions of the top level, one group *)
      val functions =
        List.mapPartial (fn (x, t, e as Lam (bs, body), g) =>
                              if isFunction e then SOME (#1 (fundef (genv, SOME g, x, bs, body, t))) else NONE
                          | _ => NONE)
                        globals

      (* each value of the top level that is no function: a suspension in a
         global, its code reading the others when it runs (a CAF), or a
         literal *)
      fun cafText (x, t, e, g) =
        if isFunction e then NONE
        else
          case e of
            Atom (Lit l) => SOME ("(val " ^ g ^ " : " ^ valTy genv t ^ " (return " ^ constText l ^ "))\n")
          | _ =>
              let
                fun peel (Lam (bs, body), TForall _) =
                      let
                        fun go (TyBinder (a, _) :: rest, env, want, tvs) =
                              (case want of
                                 TForall (b, _, w) => let val m = freshTyvar () in go (rest, bindTyvar (env, a, m), substTy ([(b, TVar a)], w), m :: tvs) end
                               | _ => raise Fail "CoreToMid: no forall")
                          | go ([], env, want, tvs) = (env, want, List.rev tvs, body)
                          | go _ = unlowered ("the polymorphic CAF " ^ x)
                      in go (bs, genv, t, []) end
                  | peel (e, TForall _) = unlowered ("the polymorphic " ^ x ^ ", bound to what is no type lambda")
                  | peel (e, t) = (genv, t, [], e)
                val (env, t', tvs, rhs) = peel (e, t)
                val V = valTy env t'
                val (def, code) = thunkCode (env, x, t', rhs, "")
                val scheme = (if null tvs then "" else "[" ^ String.concatWith " " tvs ^ "] ") ^ "(" ^ V ^ " susp)"
              in SOME ("(val " ^ g ^ " : " ^ scheme ^ " (fun " ^ def ^ " (return " ^ makeSusp (V, code) ^ ")))\n") end

      val cafs = List.mapPartial cafText globals

      (* main, run under a handler that says what no handler took and ends
         with status 1, as Core's interpreter does *)
      val main =
        case List.find (fn (x, _, _, _) => x = "main") globals of
          NONE => ""
        | SOME (_, t, _, _) =>
            let
              val R = case stripEval t of TFun (_, r) => valTy genv r | _ => raise Fail "CoreToMid: main is no function"
              val x = freshVar ()
              val run =
                atomValue (genv, Var "main", fn (m, _) => letv (R, "(app " ^ m ^ " ())", fn _ => "(return ())"))
              val handler =
                letv ("string", "(app grtExnName " ^ x ^ ")", fn n =>
                  letv ("string", "(app grtEndText " ^ x ^ ")", fn msg =>
                    letv ("string", "(prim string_concat \"rhc: bottom: \" " ^ n ^ " : (string * string) -> string)", fn a =>
                      letv ("string", "(prim string_concat " ^ a ^ " \": \" : (string * string) -> string)", fn b =>
                        letv ("string", "(prim string_concat " ^ b ^ " " ^ msg ^ " : (string * string) -> string)", fn d =>
                          letv ("string", "(prim string_concat " ^ d ^ " \"\\n\" : (string * string) -> string)", fn e =>
                            letv ("unit", "(prim print_err " ^ e ^ " : string -> unit)", fn _ =>
                              letv ("unit", "(prim exit 1 : int -> unit)", fn _ => "(return ())"))))))))
            in "(do () (handle " ^ x ^ " " ^ run ^ " " ^ handler ^ "))\n" end
    in
      {text = concat (datatypes @ [prelude]
              @ List.mapPartial (fn {name, midText, ...} : CorePrimFamily.family =>
                                   if member (name, !familiesUsed) then SOME midText else NONE)
                                CorePrim.families
              @ List.map integerDef (List.rev (!integerLits))
              @ List.map importText importGlobals
              @ (if null functions then [] else ["(funs\n  " ^ String.concatWith "\n  " functions ^ ")\n"])
              @ cafs @ [main]),
       names = List.map (fn (x, _, _, g) => (x, g)) globals @ List.map (fn (x, _, g, _) => (x, g)) importGlobals
               @ List.map (fn g => (g, g)) shared,
       abi = List.map (fn (x, _, e, _) => (x, if isFunction e then Function
                                               else case e of Atom (Lit _) => Literal | _ => Suspension)) globals
             @ (if makesShared then List.map (fn g => (g, Literal)) shared else []),
       boxed = List.mapPartial (fn Newtype (t, _, _, _) => if List.exists (fn (n, _) => n = t) newtypes then NONE
                                                          else SOME (t, boxedNewtype t)
                                 | _ => NONE) prog}
    end

  fun program ({fault}, prog) = #text (compile ({fault = fault, imports = NONE, makesShared = true, newtypes = []}, prog))
  fun unit ({fault, imports, makesShared, newtypes}, prog) =
    compile ({fault = fault, imports = SOME imports, makesShared = makesShared, newtypes = newtypes}, prog)
end
