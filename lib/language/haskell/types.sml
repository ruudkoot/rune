(* Implements: HS_TYPES *)
structure HsTypes :> HS_TYPES =
struct
  (* ---- kinds ---- *)

  datatype kind = KStar | KFun of kind * kind | KVar of kvar ref
  and kvar = KFree of int | KLink of kind

  val kcounter = ref 0
  fun newKind () = (kcounter := !kcounter + 1; KVar (ref (KFree (!kcounter))))

  fun kindRepr (KVar (r as ref (KLink k))) = let val k' = kindRepr k in r := KLink k'; k' end
    | kindRepr k = k

  fun defaultKind k =
    case kindRepr k of
      KVar r => (r := KLink KStar; KStar)
    | KFun (a, b) => KFun (defaultKind a, defaultKind b)
    | KStar => KStar

  fun showKind k =
    case kindRepr k of
      KStar => "*"
    | KVar _ => "*"
    | KFun (a, b) =>
        (case kindRepr a of KFun _ => "(" ^ showKind a ^ ")" | _ => showKind a) ^ " -> " ^ showKind b

  exception KindMismatch of kind * kind

  fun kindOccurs (r, k) =
    case kindRepr k of
      KVar r' => r = r'
    | KFun (a, b) => kindOccurs (r, a) orelse kindOccurs (r, b)
    | KStar => false

  fun unifyKind (a, b) =
    case (kindRepr a, kindRepr b) of
      (KVar r, KVar r') => if r = r' then () else r := KLink (KVar r')
    | (KVar r, k) => if kindOccurs (r, k) then raise KindMismatch (a, b) else r := KLink k
    | (k, KVar r) => if kindOccurs (r, k) then raise KindMismatch (a, b) else r := KLink k
    | (KStar, KStar) => ()
    | (KFun (a1, b1), KFun (a2, b2)) => (unifyKind (a1, a2); unifyKind (b1, b2))
    | _ => raise KindMismatch (a, b)

  (* ---- types ---- *)

  type rigid = {id : int, name : string}

  datatype ty =
      TCon of string
    | TAp of ty * ty
    | TMeta of meta ref
    | TGen of int
    | TRigid of rigid
  and meta =
      Free of {id : int, level : int, home : string}
    | Link of ty

  type pred = {cls : string, ty : ty}
  type scheme = {vars : int, ctx : pred list, ty : ty}

  val unitCon = "()"
  val listCon = "[]"
  val arrowCon = "->"
  fun tupleCon n = "(" ^ CharVector.tabulate (n - 1, fn _ => #",") ^ ")"

  fun isTupleCon s = size s >= 3 andalso String.sub (s, 0) = #"(" andalso String.sub (s, 1) = #","

  fun builtinKind name =
    let fun arrows 0 = KStar | arrows n = KFun (KStar, arrows (n - 1))
    in
      if name = unitCon then SOME KStar
      else if name = listCon then SOME (arrows 1)
      else if name = arrowCon then SOME (arrows 2)
      else if isTupleCon name then SOME (arrows (size name - 1))
      else NONE
    end

  fun fn_ (a, b) = TAp (TAp (TCon arrowCon, a), b)
  fun list t = TAp (TCon listCon, t)
  fun apply (t, args) = List.foldl (fn (a, f) => TAp (f, a)) t args
  fun tuple ts = apply (TCon (tupleCon (length ts)), ts)
  val unit = TCon unitCon

  fun repr (TMeta (r as ref (Link t))) = let val t' = repr t in r := Link t'; t' end
    | repr t = t

  fun spine t =
    let
      fun go (t, args) =
        case repr t of
          TAp (f, a) => go (f, a :: args)
        | h => (h, args)
    in
      go (t, [])
    end

  val counter = ref 0
  fun newMeta (level, home) = (counter := !counter + 1; TMeta (ref (Free {id = !counter, level = level, home = home})))

  fun renumber n = (if !counter < n then counter := n else (); if !kcounter < n then kcounter := n else ())
  fun numberFrom n = (counter := n; kcounter := n)

  fun zonk t =
    case repr t of
      TAp (a, b) => TAp (zonk a, zonk b)
    | t' => t'

  fun metaId (ref (Free {id, ...})) = id | metaId _ = ~1
  fun metaLevel (ref (Free {level, ...})) = level | metaLevel _ = ~1
  fun metaHome (ref (Free {home, ...})) = home | metaHome _ = ""
  fun setLevel (r as ref (Free {id, home, ...}), level) = r := Free {id = id, level = level, home = home}
    | setLevel _ = ()

  fun metas t =
    let
      fun go (t, acc) =
        case repr t of
          TMeta r => if List.exists (fn r' => r' = r) acc then acc else r :: acc
        | TAp (a, b) => go (b, go (a, acc))
        | _ => acc
    in
      List.rev (go (t, []))
    end

  exception Mismatch of ty * ty
  exception Occurs of ty * ty

  (* the variable r occurs in t; on the way, every variable of t is made
     no deeper than r *)
  fun occursAdjust (r, level, t) =
    case repr t of
      TMeta r' => if r = r' then true else (if metaLevel r' > level then setLevel (r', level) else (); false)
    | TAp (a, b) => occursAdjust (r, level, a) orelse occursAdjust (r, level, b)
    | _ => false

  fun unify watch (a, b) =
    let
      fun go (a, b) =
        case (repr a, repr b) of
          (TMeta r, TMeta r') =>
            (* the deeper variable is bound to the shallower, which keeps its level and its home *)
            if r = r' then () else if metaLevel r >= metaLevel r' then bind (r, TMeta r') else bind (r', TMeta r)
        | (TMeta r, t) => bind (r, t)
        | (t, TMeta r) => bind (r, t)
        | (TCon c, TCon c') => if c = c' then () else raise Mismatch (a, b)
        | (TRigid {id, ...}, TRigid {id = id', ...}) => if id = id' then () else raise Mismatch (a, b)
        | (TAp (f, x), TAp (f', x')) => (go (f, f'); go (x, x'))
        | (TGen i, TGen j) => if i = j then () else raise Mismatch (a, b)
        | _ => raise Mismatch (a, b)
      and bind (r, t) =
        (if occursAdjust (r, metaLevel r, t) then raise Occurs (TMeta r, t) else ();
         watch (r, t);
         r := Link t)
    in
      go (a, b)
    end

  fun substGen (ts, t) =
    case repr t of
      TGen i => List.nth (ts, i)
    | TAp (a, b) => TAp (substGen (ts, a), substGen (ts, b))
    | t' => t'

  fun instantiate ({vars, ctx, ty} : scheme, level, home) =
    let
      val ts = List.tabulate (vars, fn _ => newMeta (level, home))
    in
      (ts, List.map (fn {cls, ty} => {cls = cls, ty = substGen (ts, ty)}) ctx, substGen (ts, ty))
    end

  (* ---- showing ---- *)

  fun nameOfKey k =
    let
      fun go i = if i >= size k then k else if String.sub (k, i) = #"\t" then String.extract (k, i + 1, NONE) else go (i + 1)
    in
      go 0
    end

  (* a rigid variable's name as written: a signature's `a_12` is `a` *)
  fun written name =
    let
      fun go i =
        if i <= 0 then name
        else if Char.isDigit (String.sub (name, i)) then go (i - 1)
        else if String.sub (name, i) = #"_" andalso i < size name - 1 then String.substring (name, 0, i)
        else name
    in
      go (size name - 1)
    end

  fun letters i = if i < 26 then str (Char.chr (97 + i)) else letters (i div 26 - 1) ^ str (Char.chr (97 + i mod 26))

  fun showWith gen =
    let
      fun atomic t = case repr t of TAp _ => false | _ => true
      fun go (prec, t) =
        case spine t of
          (TCon c, args) =>
            if isTupleCon c andalso length args = size c - 1 then "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ")"
            else
              (case args of
                 [a, b] => if c = arrowCon then paren (prec > 0, go (1, a) ^ " -> " ^ go (0, b)) else app (prec, c, [a, b])
               | [a] => if c = listCon then "[" ^ go (0, a) ^ "]" else app (prec, c, [a])
               | _ => app (prec, c, args))
        | (h, []) => head h
        | (h, args) => paren (prec > 1, head h ^ " " ^ String.concatWith " " (List.map (fn a => go (2, a)) args))
      and app (prec, c, []) = nameOfKey c
        | app (prec, c, args) = paren (prec > 1, nameOfKey c ^ " " ^ String.concatWith " " (List.map (fn a => go (2, a)) args))
      and head t =
        case repr t of
          TCon c => nameOfKey c
        | TMeta r => "t" ^ Int.toString (metaId r)
        | TGen i => gen i
        | TRigid {name, ...} => written name
        | TAp _ => go (2, t)
      and paren (true, s) = "(" ^ s ^ ")"
        | paren (false, s) = s
    in
      fn t => go (0, t)
    end

  val show = showWith (fn i => letters i)

  fun showPred {cls, ty} =
    let val t = show ty
    in nameOfKey cls ^ " " ^ (if CharVector.exists (fn c => c = #" ") t andalso not (String.isPrefix "[" t) andalso not (String.isPrefix "(" t) then "(" ^ t ^ ")" else t) end

  fun showScheme ({ctx, ty, ...} : scheme) =
    (case ctx of
       [] => ""
     | [p] => showPred p ^ " => "
     | ps => "(" ^ String.concatWith ", " (List.map showPred ps) ^ ") => ") ^ show ty
end
