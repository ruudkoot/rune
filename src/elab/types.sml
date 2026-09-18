(* Internal representation of types for elaboration. *)
structure Types =
struct
  (* A type name (Definition, Section 4.1): a generative stamp with an arity
     and an equality attribute. Names are compared by stamp only. *)
  type tycon = {name : string, stamp : int, arity : int, eq : bool}

  datatype ty =
      TVar of tvar ref
    | TCon of tycon * ty list
    | TRecord of (string * ty) list         (* labels sorted by labelCompare *)
    | TArrow of ty * ty

  and tvar =
      Unbound of {id : int, level : int, kind : kind, eq : bool}
    | Bound of ty

  and kind =
      KPlain
    | KRigid of string                     (* explicit type variable in scope (Section 4.6): unifies with nothing but variables *)
    | KOverload of string list             (* names of admissible builtin tycons *)
    | KFlex of (string * ty) list * flexgroup
        (* known fields of a flexible record, and the variables that stand
           for the same record (a generalised one and its instances): when
           one of them learns its full set of labels, all of them do *)

  withtype flexgroup = tvar ref list ref

  (* A type function (Section 4.4): a type name, or an abbreviation whose
     parameters are the ids of generic variables occurring in the body. *)
  datatype tyfcn =
      TName of tycon
    | TAbbrev of int list * ty

  (* A type scheme is a type whose generic variables have level = genericLevel. *)
  type scheme = ty

  val genericLevel = 1000000000

  fun sameTycon (a : tycon, b : tycon) = #stamp a = #stamp b

  (* --- builtin type constructors --- *)
  fun mk (name, stamp, arity, eq) : tycon = {name = name, stamp = stamp, arity = arity, eq = eq}
  val intTycon = mk ("int", 1, 0, true)
  val wordTycon = mk ("word", 2, 0, true)
  val realTycon = mk ("real", 3, 0, false)
  val charTycon = mk ("char", 4, 0, true)
  val stringTycon = mk ("string", 5, 0, true)
  val boolTycon = mk ("bool", 6, 0, true)
  val listTycon = mk ("list", 7, 1, true)
  val refTycon = mk ("ref", 8, 1, true)
  val exnTycon = mk ("exn", 9, 0, false)
  val arrayTycon = mk ("array", 10, 1, true)
  val vectorTycon = mk ("vector", 11, 1, true)

  val builtinTycons =
    [intTycon, wordTycon, realTycon, charTycon, stringTycon, boolTycon, listTycon, refTycon,
     exnTycon, arrayTycon, vectorTycon]

  (* Is c one of the builtin type names (by stamp)? *)
  fun isBuiltinTycon (c : tycon) = List.exists (fn b => sameTycon (b, c)) builtinTycons

  val intTy = TCon (intTycon, [])
  val wordTy = TCon (wordTycon, [])
  val realTy = TCon (realTycon, [])
  val charTy = TCon (charTycon, [])
  val stringTy = TCon (stringTycon, [])
  val boolTy = TCon (boolTycon, [])
  val exnTy = TCon (exnTycon, [])
  val unitTy = TRecord []
  fun listTy t = TCon (listTycon, [t])
  fun refTy t = TCon (refTycon, [t])
  fun arrayTy t = TCon (arrayTycon, [t])
  fun vectorTy t = TCon (vectorTycon, [t])

  val tyconCounter = ref 100
  fun freshTycon (name, arity, eq) : tycon =
    let val s = !tyconCounter in tyconCounter := s + 1; mk (name, s, arity, eq) end

  (* The same name with another equality attribute. *)
  fun withEq (c : tycon, eq) : tycon = mk (#name c, #stamp c, #arity c, eq)

  val tvarCounter = ref 0
  fun freshTvar (level, kind, eq) =
    let val id = !tvarCounter
    in tvarCounter := id + 1; TVar (ref (Unbound {id = id, level = level, kind = kind, eq = eq})) end
  fun fresh level = freshTvar (level, KPlain, false)

  (* A new flexible record variable, alone in its group. *)
  fun freshFlex (level, fields, eq) : ty =
    let
      val group : flexgroup = ref []
      val t = freshTvar (level, KFlex (fields, group), eq)
    in
      (case t of TVar r => group := [r] | _ => ());
      t
    end

  (* A flexible record variable linked to the group of another one. *)
  fun freshFlexIn (level, fields, eq, group : flexgroup) : ty =
    let val t = freshTvar (level, KFlex (fields, group), eq)
    in (case t of TVar r => group := r :: !group | _ => ()); t end

  (* --- record labels --- *)
  fun isNumericLabel s =
    String.size s > 0 andalso String.sub (s, 0) <> #"0" andalso List.all Char.isDigit (String.explode s)

  fun labelCompare (a, b) =
    case (isNumericLabel a, isNumericLabel b) of
      (true, true) =>
        if String.size a <> String.size b then Int.compare (String.size a, String.size b)
        else String.compare (a, b)
    | (true, false) => LESS
    | (false, true) => GREATER
    | (false, false) => String.compare (a, b)

  fun sortFields (fields : (string * 'a) list) =
    let
      fun ins (f, []) = [f]
        | ins (f as (l, _), (g as (l', _)) :: rest) =
          if labelCompare (l, l') = GREATER then g :: ins (f, rest) else f :: g :: rest
    in List.foldl ins [] fields end

  fun tupleTy tys =
    TRecord (ListPair.zip (List.tabulate (List.length tys, fn i => Int.toString (i + 1)), tys))

  fun isTuple fields =
    let fun go (_, []) = true
          | go (i, (l, _) :: rest) = l = Int.toString i andalso go (i + 1, rest)
    in List.length fields >= 2 andalso go (1, fields) end

  (* Index of a label in a sorted field list. *)
  fun labelIndex (fields : (string * 'a) list, lab) =
    let fun go (_, []) = NONE
          | go (i, (l, _) :: rest) = if l = lab then SOME i else go (i + 1, rest)
    in go (0, fields) end

  (* --- resolving variable links --- *)
  fun prune (t as TVar r) = (case !r of Bound t' => let val t'' = prune t' in r := Bound t''; t'' end | _ => t)
    | prune t = t

  (* Fully dereference (for the backend). *)
  fun resolve t =
    case prune t of
      TVar r => TVar r
    | TCon (c, args) => TCon (c, List.map resolve args)
    | TRecord fs => TRecord (List.map (fn (l, t) => (l, resolve t)) fs)
    | TArrow (a, b) => TArrow (resolve a, resolve b)

  (* --- type functions --- *)
  fun fcnArity (TName c) = #arity c
    | fcnArity (TAbbrev (params, _)) = List.length params

  (* Substitute parameter variables (by id) in a type abbreviation body. *)
  fun substitute (params : int list, args : ty list, body : ty) : ty =
    let
      val pairs = ListPair.zip (params, args)
      fun copy t =
        case prune t of
          t as TVar r =>
            (case !r of
               Unbound {id, ...} =>
                 (case List.find (fn (i, _) => i = id) pairs of SOME (_, a) => a | NONE => t)
             | Bound _ => t)
        | TCon (c, args) => TCon (c, List.map copy args)
        | TRecord fields => TRecord (List.map (fn (l, a) => (l, copy a)) fields)
        | TArrow (a, b) => TArrow (copy a, copy b)
    in copy body end

  fun applyFcn (TName c, args) = TCon (c, args)
    | applyFcn (TAbbrev (params, body), args) = substitute (params, args, body)

  (* The type name a type function is eta-equivalent to, if any. *)
  fun fcnIsName (TName c) = SOME c
    | fcnIsName (TAbbrev (params, body)) =
      (case prune body of
         TCon (c, args) =>
           let
             fun isParam (p, a) = case prune a of TVar (ref (Unbound {id, ...})) => id = p | _ => false
           in
             if List.length args = List.length params andalso ListPair.all isParam (params, args) then SOME c
             else NONE
           end
       | _ => NONE)

  (* A realisation (Section 5.6) maps type names, by stamp, to type functions. *)
  type realisation = tyfcn IntMap.map

  fun realize (phi : realisation, t : ty) : ty =
    case prune t of
      t as TVar _ => t
    | TCon (c, args) =>
        let val args' = List.map (fn a => realize (phi, a)) args
        in
          case IntMap.find (phi, #stamp c) of
            SOME f => applyFcn (f, args')
          | NONE => TCon (c, args')
        end
    | TRecord fields => TRecord (List.map (fn (l, a) => (l, realize (phi, a))) fields)
    | TArrow (a, b) => TArrow (realize (phi, a), realize (phi, b))

  fun realizeFcn (phi : realisation, f : tyfcn) : tyfcn =
    case f of
      TName c => (case IntMap.find (phi, #stamp c) of SOME f' => f' | NONE => f)
    | TAbbrev (params, body) => TAbbrev (params, realize (phi, body))

  (* --- equality (Section 4.4) --- *)
  (* Does a type admit equality? Type variables count as admitting it: for
     type functions their parameters are assumed to, and for unification
     variables the equality attribute is enforced when they are bound. *)
  fun admitsEq (t : ty) : bool =
    case prune t of
      TVar _ => true
    | TCon (c, args) =>
        sameTycon (c, refTycon) orelse sameTycon (c, arrayTycon)
        orelse (#eq c andalso List.all admitsEq args)
    | TRecord fields => List.all (fn (_, a) => admitsEq a) fields
    | TArrow _ => false

  fun fcnAdmitsEq (TName c) = #eq c
    | fcnAdmitsEq (TAbbrev (_, body)) = admitsEq body

  (* Structural equality of two (pruned) types. *)
  fun equalTy (t1 : ty, t2 : ty) : bool =
    case (prune t1, prune t2) of
      (TVar r1, TVar r2) => r1 = r2
    | (TCon (c1, a1), TCon (c2, a2)) =>
        sameTycon (c1, c2) andalso List.length a1 = List.length a2 andalso ListPair.all equalTy (a1, a2)
    | (TRecord f1, TRecord f2) =>
        List.length f1 = List.length f2
        andalso ListPair.all (fn ((l1, a), (l2, b)) => l1 = l2 andalso equalTy (a, b)) (f1, f2)
    | (TArrow (a1, b1), TArrow (a2, b2)) => equalTy (a1, a2) andalso equalTy (b1, b2)
    | _ => false

  (* Equality of type functions: apply both to the same fresh names. *)
  fun fcnEqual (f1 : tyfcn, f2 : tyfcn) : bool =
    fcnArity f1 = fcnArity f2
    andalso
    let val args = List.tabulate (fcnArity f1, fn _ => TCon (freshTycon ("?", 0, true), []))
    in equalTy (applyFcn (f1, args), applyFcn (f2, args)) end

  (* --- pretty printing --- *)
  (* Printer state shared by the types of one message: type variable names,
     and the type names seen so far (distinct names that share a name are
     told apart by their stamp). *)
  type printer = {names : (int * string) list ref, tycons : (string * int) list ref}
  fun newPrinter () : printer = {names = ref [], tycons = ref []}

  fun toStringWith ({names, tycons} : printer) t =
    let
      fun tcName (c : tycon) =
        case List.find (fn (n, _) => n = #name c) (!tycons) of
          SOME (_, s) => if s = #stamp c then #name c else #name c ^ "/" ^ Int.toString (#stamp c)
        | NONE => (tycons := (#name c, #stamp c) :: !tycons; #name c)
      fun tvName (id, eq) =
        case List.find (fn (i, _) => i = id) (!names) of
          SOME (_, s) => s
        | NONE =>
          let
            val k = List.length (!names)
            val base = if k < 26 then String.str (Char.chr (Char.ord #"a" + k))
                       else "t" ^ Int.toString k
            val s = (if eq then "''" else "'") ^ base
          in names := (id, s) :: !names; s end
      fun paren (b, s) = if b then "(" ^ s ^ ")" else s
      (* prec: 0 = top, 1 = arrow domain, 2 = tuple operand, 3 = tycon argument *)
      fun go (prec, t) =
        case prune t of
          TVar r =>
            (case !r of
               Unbound {id, kind = KPlain, eq, ...} => tvName (id, eq)
             | Unbound {kind = KRigid name, ...} => name
             | Unbound {id, kind = KOverload _, ...} => tvName (id, false)
             | Unbound {kind = KFlex (fields, _), ...} =>
                 "{" ^ String.concatWith ", " (List.map (fn (l, t) => l ^ " : " ^ go (0, t)) fields) ^ ", ...}"
             | Bound _ => "?")
        | TCon (c, []) => tcName c
        | TCon (c, [a]) => go (3, a) ^ " " ^ tcName c
        | TCon (c, args) => "(" ^ String.concatWith ", " (List.map (fn a => go (0, a)) args) ^ ") " ^ tcName c
        | TRecord [] => "unit"
        | TRecord fields =>
            if isTuple fields then
              paren (prec >= 2, String.concatWith " * " (List.map (fn (_, t) => go (2, t)) fields))
            else "{" ^ String.concatWith ", " (List.map (fn (l, t) => l ^ " : " ^ go (0, t)) fields) ^ "}"
        | TArrow (a, b) => paren (prec >= 1, go (1, a) ^ " -> " ^ go (0, b))
    in go (0, t) end

  fun toString t = toStringWith (newPrinter ()) t
end
