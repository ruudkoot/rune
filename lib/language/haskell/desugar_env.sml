(* Implements: HS_DS_ENV *)
structure HsDsEnv :> HS_DS_ENV =
struct
  structure M = HsStringMap
  structure T = HsTypes
  structure E = HsEvidence
  structure C = HsDsCore

  type program = {infer : HsInfer.env, evidence : HsEvidence.table, prelude : string * string -> string option,
                  library : string -> bool, entity : string * string * string -> string}

  val current : program option ref = ref NONE
  val primTypes : string M.map ref = ref M.empty
  val builtinCons : string M.map ref = ref M.empty
  val conFields : string list M.map ref = ref M.empty

  fun start p = (current := SOME p; primTypes := M.empty; builtinCons := M.empty; conFields := M.empty)

  fun prog () = case !current of SOME p => p | NONE => raise Fail "HsDsEnv: no program"

  fun classes () = HsInfer.classes (#infer (prog ()))
  fun valueScheme k = HsInfer.valueScheme (#infer (prog ()), k)

  fun prelude (space, name) =
    case #prelude (prog ()) (space, name) of
      SOME k => k
    | NONE => raise Fail ("HsDsEnv: the Prelude exports no " ^ name)

  fun isLibrary id = #library (prog ()) id

  fun libraryEntity e = #entity (prog ()) e

  fun setFields (k, fs) = conFields := M.insert (!conFields, k, fs)
  fun fieldsOf k = getOpt (M.find (!conFields, k), [])

  (* ---- Names ---- *)

  fun valueKey (HsAst.Name (_, {qual, name})) =
    if qual = "" then name else HsModules.key {space = HsModules.Value, home = qual, name = name}

  (* a key's module and name: `s<home>\t<name>`, or a built-in name *)
  fun split k =
    case CharVector.findi (fn (_, c) => c = #"\t") k of
      SOME (i, _) => (String.substring (k, 1, i - 1), String.extract (k, i + 1, NONE))
    | NONE => ("", k)

  fun homeOf k = #1 (split k)
  fun nameOf k = #2 (split k)

  fun coreName k = case split k of ("", n) => n | (h, n) => h ^ "." ^ n

  fun primType (k, c) = primTypes := M.insert (!primTypes, k, c)
  fun isPrimType k = M.member (!primTypes, k)

  fun tyconName k = case M.find (!primTypes, k) of SOME c => c | NONE => coreName k

  fun builtinCon (k, c) = builtinCons := M.insert (!builtinCons, k, c)

  fun conName k = case M.find (!builtinCons, k) of SOME c => c | NONE => coreName k

  fun dictCon cls = "%dict:" ^ coreName cls

  fun dfunName id =
    case CharVector.findi (fn (_, c) => c = #"@") id of
      SOME (i, _) => "%inst:" ^ coreName (String.substring (id, 0, i)) ^ "@" ^ coreName (String.extract (id, i + 1, NONE))
    | NONE => "%inst:" ^ id

  fun superName (c, s) = "%super:" ^ coreName c ^ ">" ^ coreName s

  fun defaultName m = "%dm:" ^ coreName m

  (* ---- Scopes ---- *)

  type env = {vars : (Core.atom * Core.ty) M.map, tyvars : Core.kind M.map}

  val empty : env = {vars = M.empty, tyvars = M.empty}

  fun bind ({vars, tyvars} : env, x, a, t) : env = {vars = M.insert (vars, x, (a, t)), tyvars = tyvars}

  fun lookup ({vars, ...} : env, x) = M.find (vars, x)

  fun bindTypes ({vars, tyvars} : env, vs) : env =
    {vars = vars, tyvars = List.foldl (fn ((a, k), m) => M.insert (m, a, k)) tyvars vs}

  fun typeVars ({tyvars, ...} : env) = M.listItems tyvars

  (* ---- Types ---- *)

  fun conv (env : env, gens : Core.ty list) t =
    let
      val (h, args) = T.spine t
      val cargs = List.map (conv (env, gens)) args
      fun applied c = Core.apply (c, cargs)
    in
      case T.repr h of
        T.TCon k =>
          if k = T.arrowCon then
            (case cargs of
               [a, b] => Core.TFun (a, b)
             | _ => raise Fail "HsDsEnv: the function type constructor applied to other than two types")
          else applied (Core.TCon (tyconName k))
      | T.TRigid {name, ...} =>
          if M.member (#tyvars env, name) then applied (Core.TVar name)
          else if null cargs then C.unitTy
          else applied (Core.TVar name)
      | T.TGen i =>
          if i < length gens then applied (List.nth (gens, i))
          else raise Fail "HsDsEnv: a scheme's variable out of range"
      | T.TMeta _ => C.unitTy
      | T.TAp _ => raise Fail "HsDsEnv: a type's spine"
    end

  fun ty env t = conv (env, []) t
  fun tyGen (env, gens) t = conv (env, gens) t

  fun predTy env ({cls, ty = t} : T.pred) = Core.TApp (Core.TCon (tyconName cls), ty env t)

  fun foralls (ks, t) = List.foldr (fn ((a, k), r) => Core.TForall (a, k, r)) t ks

  fun scheme env ({vars, ctx, ty = t} : E.scheme) =
    let
      val env' = bindTypes (env, List.map (fn v => (v, Core.Star)) vars)
      val dts = List.map (predTy env') ctx
      val body = ty env' t
      val ks = C.inferKinds (vars, fn a => M.find (#tyvars env, a), dts @ [body])
    in
      (foralls (ks, List.foldr Core.TFun body dts), ks)
    end

  fun genScheme ({vars, ctx, ty = t} : T.scheme) =
    let
      val names = List.tabulate (vars, fn i => "g" ^ Int.toString (i + 1))
      val gens = List.map Core.TVar names
      val dts = List.map (fn {cls, ty = u} => Core.TApp (Core.TCon (tyconName cls), tyGen (empty, gens) u)) ctx
      val body = tyGen (empty, gens) t
      val ks = C.inferKinds (names, fn _ => NONE, dts @ [body])
    in
      foralls (ks, List.foldr Core.TFun body dts)
    end

  fun ioTy t = Core.TApp (Core.TCon "IO", t)

  (* ---- Records ---- *)

  fun records (kind, span) = E.find (#evidence (prog ()), E.node (kind, span))

  fun useOf span =
    case List.find (fn E.Use _ => true | _ => false) (records ("use", span)) of
      SOME (E.Use r) => r
    | _ => {tys = [], dicts = []}

  fun bindOf span = case records ("bind", span) of r :: _ => SOME r | [] => NONE

  fun overloadedOf (kind, span) =
    case List.find (fn E.Overloaded _ => true | _ => false) (records (kind, span)) of
      SOME (E.Overloaded {ty = t, dicts}) => (t, dicts)
    | _ => raise Fail ("HsDsEnv: no record " ^ E.node (kind, span))

  (* ---- Expressions ---- *)

  fun declared name =
    case C.valueType name of
      SOME t => C.var (name, t)
    | NONE => raise Fail ("HsDsEnv: " ^ name ^ " is not declared")

  fun global key = declared (coreName key)

  (* the type a dictionary is of, its class's applied to it *)
  fun dictArg t =
    case Core.stripEval t of
      Core.TApp (_, a) => a
    | t' => raise Fail ("HsDsEnv: " ^ CoreText.showTy t' ^ " is no dictionary's type")

  fun dict env d =
    case d of
      E.DParam p =>
        (case lookup (env, p) of
           SOME (a, t) => (Core.Atom a, t)
         | NONE => raise Fail ("HsDsEnv: the dictionary parameter " ^ p ^ " is not in scope"))
    | E.DInst {inst, tys, args} =>
        C.appAtoms (C.app (declared (dfunName inst), List.map (Core.TyArg o ty env) tys), List.map (dict env) args)
    | E.DSuper {dict = d', cls, super} =>
        let val x = dict env d'
        in C.appAtoms (C.app (declared (superName (cls, super)), [Core.TyArg (dictArg (#2 x))]), [x]) end

  fun instantiate env (f, tys, dicts) =
    C.appAtoms (C.app (f, List.map (Core.TyArg o ty env) tys), List.map (dict env) dicts)

  fun method env (key, tys, dicts) = C.appAtoms (C.app (global key, List.map Core.TyArg tys), dicts)

  fun superDict env (d, cls, super) =
    case HsClasses.superPath (classes (), cls, super) of
      SOME path =>
        let
          fun walk (d, c :: (rest as s :: _)) = walk (E.DSuper {dict = d, cls = c, super = s}, rest)
            | walk (d, _) = d
        in
          walk (d, path)
        end
    | NONE => raise Fail ("HsDsEnv: " ^ coreName super ^ " is no superclass of " ^ coreName cls)

  (* ---- Literals ---- *)

  (* the type constructor of the instance a dictionary is, where it is one
     at no types *)
  fun knownTycon d =
    case d of
      E.DInst {inst, tys = [], args = []} =>
        (case CharVector.findi (fn (_, c) => c = #"@") inst of
           SOME (i, _) => SOME (String.extract (inst, i + 1, NONE))
         | NONE => NONE)
    | _ => NONE

  fun isPrelude (d, name) =
    case knownTycon d of
      SOME tc => (case #prelude (prog ()) ("t", name) of SOME k => k = tc | NONE => false)
    | NONE => false

  fun litAtom l = (Core.Atom (Core.Lit l), Core.TEval (Core.litTy l))

  fun inIntRange i = (ignore (Int.fromLarge i); true) handle Overflow => false

  fun integerLit env (i, t, num) =
    if isPrelude (num, "Int") andalso inIntRange i then litAtom (Core.LInt i)
    else if isPrelude (num, "Integer") then litAtom (Core.LInteger i)
    else C.appAtoms (method env (prelude ("v", "fromInteger"), [ty env t], [dict env num]), [litAtom (Core.LInteger i)])

  (* the value of a floating literal's text, n / d in lowest terms *)
  fun rational text =
    let
      val s = String.map Char.toLower text
      val (mant, ex) =
        case CharVector.findi (fn (_, c) => c = #"e") s of
          SOME (i, _) => (String.substring (s, 0, i), String.extract (s, i + 1, NONE))
        | NONE => (s, "0")
      val (whole, frac) =
        case CharVector.findi (fn (_, c) => c = #".") mant of
          SOME (i, _) => (String.substring (mant, 0, i), String.extract (mant, i + 1, NONE))
        | NONE => (mant, "")
      val zero = IntInf.fromInt 0
      val ten = IntInf.fromInt 10
      fun digits str = List.foldl (fn (c, acc) => IntInf.+ (IntInf.* (acc, ten), IntInf.fromInt (Char.ord c - 48))) zero (explode str)
      val e = case ex of
                "" => 0
              | _ => (case String.sub (ex, 0) of
                        #"-" => ~ (IntInf.toInt (digits (String.extract (ex, 1, NONE))))
                      | #"+" => IntInf.toInt (digits (String.extract (ex, 1, NONE)))
                      | _ => IntInf.toInt (digits ex))
      val n0 = digits (whole ^ frac)
      val e' = e - size frac
      val (n, d) = if e' >= 0 then (IntInf.* (n0, IntInf.pow (ten, e')), IntInf.fromInt 1) else (n0, IntInf.pow (ten, ~e'))
      fun gcd (a, b) = if b = zero then a else gcd (b, IntInf.rem (a, b))
      val g = gcd (n, d)
    in
      if g = zero then (zero, IntInf.fromInt 1) else (IntInf.quot (n, g), IntInf.quot (d, g))
    end

  fun rationalLit env (text, t, frac) =
    if isPrelude (frac, "Double") then litAtom (Core.LDouble text)
    else if isPrelude (frac, "Float") then litAtom (Core.LFloat text)
    else
      let
        val (n, d) = rational text
        val r = C.con (conName (libraryEntity ("v", "Ratio", ":%")), [Core.TCon "Integer"],
                       [litAtom (Core.LInteger n), litAtom (Core.LInteger d)])
      in
        C.appAtoms (method env (prelude ("v", "fromRational"), [ty env t], [dict env frac]), [r])
      end

  (* a code point in UTF-8 *)
  fun utf8 c =
    let
      fun byte b = str (Char.chr b)
      (* the six bits of v above the lowest `below` *)
      fun cont (v, below) = byte (128 + (v div below) mod 64)
    in
      if c < 128 then byte c
      else if c < 2048 then byte (192 + c div 64) ^ cont (c, 1)
      else if c < 65536 then byte (224 + c div 4096) ^ cont (c, 64) ^ cont (c, 1)
      else byte (240 + c div 262144) ^ cont (c, 4096) ^ cont (c, 64) ^ cont (c, 1)
    end

  fun stringLit [] = C.con ("[]", [Core.TCon "Char"], [])
    | stringLit cs =
        C.appAtoms (declared "primUnpackString", [litAtom (Core.LStr (String.concat (List.map utf8 cs)))])

  (* ---- Core's own types as Haskell sees them ---- *)

  val world = Core.TCon "World"

  fun haskellForm t =
    case t of
      Core.TEval u => haskellForm u
    | Core.TFun (Core.TCon "World", Core.TUTuple [Core.TCon "World", x]) => ioTy (haskellForm x)
    | Core.TFun (Core.TCon "World", Core.TCon "World") => ioTy C.unitTy
    | Core.TFun (a, b) => Core.TFun (haskellForm a, haskellForm b)
    | Core.TForall (a, k, b) => Core.TForall (a, k, haskellForm b)
    | Core.TApp (f, a) => Core.TApp (haskellForm f, haskellForm a)
    | Core.TUTuple ts => Core.TUTuple (List.map haskellForm ts)
    | _ => t

  fun matchType (p, vars, t) =
    let
      val s : (string * Core.ty) list ref = ref []
      fun m (pt, u) =
        case (pt, u) of
          (Core.TVar a, _) =>
            if List.exists (fn v => v = a) vars then
              (case List.find (fn (b, _) => b = a) (!s) of
                 SOME (_, u') => Core.equalTy (u', u)
               | NONE => (s := (a, u) :: !s; true))
            else (case u of Core.TVar b => a = b | _ => false)
        | (Core.TCon c, Core.TCon d) => c = d
        | (Core.TApp (f, a), Core.TApp (g, b)) => m (f, g) andalso m (a, b)
        | (Core.TFun (a, b), Core.TFun (c, d)) => m (a, c) andalso m (b, d)
        | _ => false
    in
      if m (haskellForm p, haskellForm t) then
        SOME (List.map (fn v => case List.find (fn (b, _) => b = v) (!s) of SOME (_, u) => u | NONE => C.unitTy) vars)
      else NONE
    end

  (* every ! of t gone *)
  fun noEval t =
    case t of
      Core.TEval u => noEval u
    | Core.TFun (a, b) => Core.TFun (noEval a, noEval b)
    | Core.TForall (a, k, b) => Core.TForall (a, k, noEval b)
    | Core.TApp (f, a) => Core.TApp (noEval f, noEval a)
    | Core.TUTuple ts => Core.TUTuple (List.map noEval ts)
    | _ => t

  fun sameUpToEval (a, b) = Core.equalTy (noEval a, noEval b)

  (* `toHaskell (x, want)`: x, of a type of Core's making, as `want` *)
  fun toHaskell ((e, have), want) =
    case (Core.stripEval have, want) of
      (Core.TForall (_, _, _), Core.TForall (a, k, w)) =>
        let val inner = toHaskell (C.app ((e, have), [Core.TyArg (Core.TVar a)]), w)
        in C.lam ([Core.TyBinder (a, k)], inner) end
    | (_, Core.TForall (a, k, w)) =>
        (* a type the primitive does not take, as exit's result *)
        C.lam ([Core.TyBinder (a, k)], toHaskell ((e, have), w))
    | (Core.TFun (Core.TCon "World", r), Core.TApp (Core.TCon "IO", t)) =>
        let
          val w = C.fresh "w"
          val call = C.app ((e, have), [Core.ValArg (Core.Var w)])
          val result = Core.TUTuple [world, t]
          val body =
            case r of
              Core.TUTuple [_, xt] =>
                let
                  val w1 = C.fresh "w"
                  val x = C.fresh "r"
                  val y = C.fresh "y"
                  val (inner, _) =
                    C.let_ (y, t, toHaskell (C.var (x, xt), t),
                            (Core.UTuple [Core.Var w1, Core.Var y], result))
                in
                  (Core.Case (#1 call, C.fresh "u", [Core.AltUTuple ([w1, x], inner)]), result)
                end
            | Core.TCon "World" =>
                let
                  val w1 = C.fresh "w"
                  val y = C.fresh "y"
                  val value = if Core.equalTy (t, C.unitTy) then C.unitVal () else C.fail ("exn_error", "an action that ends the program returned", t)
                  val (inner, _) = C.let_ (y, t, value, (Core.UTuple [Core.Var w1, Core.Var y], result))
                in
                  (Core.Case (#1 call, w1, [Core.AltDefault inner]), result)
                end
            | _ => raise Fail ("HsDsEnv: an action of " ^ CoreText.showTy have)
        in
          C.cast (C.lam ([Core.ValBinder (w, world)], body), want)
        end
    | (Core.TFun (hp, _), Core.TFun (wp, wr)) =>
        let
          val x = C.fresh "a"
          val body = toCoreAtom (C.var (x, wp), hp, fn (a, _) => toHaskell (C.app ((e, have), [Core.ValArg a]), wr))
        in
          C.lam ([Core.ValBinder (x, wp)], body)
        end
    | _ =>
        if sameUpToEval (have, want) then (e, have)
        else raise Fail ("HsDsEnv: " ^ CoreText.showTy have ^ " cannot be made " ^ CoreText.showTy want)

  (* `toCoreAtom (x, target, k)`: k given the atom of x as Core's `target`,
     evaluated where it is `!`, in the scope of the case that forces it *)
  and toCoreAtom (x, target, k) =
    case target of
      Core.TEval tt => toCoreAtom (x, tt, fn (a, t) => C.force ((Core.Atom a, t), fn (v, vt) => k (Core.Var v, vt)))
    | _ => C.atom (toCore (x, target), k)

  (* `toCore (x, target)`: x, of a Haskell type, as Core's lazy `target` *)
  and toCore ((e, et), target) =
    case (Core.stripEval et, target) of
      (_, Core.TEval tt) => toCore ((e, et), tt)
    | (Core.TApp (Core.TCon "IO", t), Core.TFun (Core.TCon "World", r)) =>
        let val rep = Core.TFun (world, Core.TUTuple [world, t])
        in
          if Core.equalTy (rep, target) then C.cast ((e, et), rep)
          else toCore (C.cast ((e, et), rep), target)
        end
    | (Core.TFun (Core.TCon "World", Core.TUTuple [_, xt]), Core.TFun (Core.TCon "World", Core.TUTuple [_, tt])) =>
        if Core.equalTy (xt, tt) then (e, et)
        else raise Fail ("HsDsEnv: an action of " ^ CoreText.showTy et ^ " made one of " ^ CoreText.showTy target)
    | (Core.TFun (wp, _), Core.TFun (hp, hr)) =>
        let
          val y = C.fresh "a"
          val body = C.atom (toHaskell (C.var (y, hp), wp), fn (a, _) => toCore (C.app ((e, et), [Core.ValArg a]), hr))
        in
          C.lam ([Core.ValBinder (y, hp)], body)
        end
    | _ =>
        if sameUpToEval (et, target) then (e, et)
        else raise Fail ("HsDsEnv: " ^ CoreText.showTy et ^ " cannot be made Core's " ^ CoreText.showTy target)
end
