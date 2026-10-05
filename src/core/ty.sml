(* The types of the intermediate representations (docs/ir.md): immutable,
   made from the elaborator's after elaboration has finished, when every
   variable of a type is either generic -- one of a scheme's -- or known to
   stand for nothing more (Gen and Var). A record is a tuple of its fields in
   the order of their labels, and a type made abstract by an opaque
   signature is what it stands for, so that the representation says what a
   value is and not what a signature lets a program see.

   The elaborator fills the tables below as it goes, so that a type can be
   found for what the translation meets: the scheme of every variable, the
   constructors of every datatype, the argument of every exception, and what
   each opaque type stands for. *)
structure Ty =
struct
  datatype ty =
      Gen of int                          (* a generic variable of a scheme, by the elaborator's id *)
    | Var of int                          (* a variable no type was found for: equal to itself only *)
    | Con of int * string * ty list       (* a type name, by stamp, and its arguments *)
    | Tuple of ty list                    (* a record or tuple; unit is Tuple [] *)
    | Arrow of ty * ty
    | ExnCon                              (* an exception constructor *)

  (* ---- the tables ---- *)

  (* the type, or scheme, each variable was bound with, by its stamp *)
  val binders : Types.ty IntTable.table = IntTable.table 8192
  (* the argument of each exception, by its stamp *)
  val exnArgs : Types.ty option IntTable.table = IntTable.table 256
  (* each datatype, by the stamp of its type name: the ids of its parameters,
     and each constructor's tag, name and argument, as the elaborator gave it
     or, for one Mid's text declares (MidText), as it is *)
  datatype argTy = FromElab of Types.ty | Direct of ty
  type datatypeInfo = {params : int list, cons : (int * string * argTy option) list}
  val datatypes : datatypeInfo IntMap.map ref = ref IntMap.empty
  (* what each type made abstract by an opaque signature stands for, by the
     stamp of its fresh name *)
  val realizations : Types.tyfcn IntTable.table = IntTable.table 256

  (* A datatype declared in a function may name the function's type
     variables (`fun 'a f ... = let datatype t = T of 'a ...`): an instance
     of the function -- inlined, specialised -- gives them other types, which
     a type of t must say for its constructors' arguments to agree. So each
     such variable is a parameter of t after its own, which every type made
     of t (fromTypes) gives as itself: the generic variables its
     constructors name that are not its parameters, and those of the
     datatypes they name. Worked out once the elaborator has given every
     datatype (extrasOf); in most programs no datatype has any. *)
  datatype extras = Unknown | NoExtras | Extras of int list IntMap.map
  val extras = ref Unknown

  fun bindVar (stamp : int, t : Types.ty) = IntTable.insert (binders, stamp, t)
  fun bindExn (stamp : int, arg : Types.ty option) = IntTable.insert (exnArgs, stamp, arg)
  fun bindDatatype (stamp : int, {params, cons} : {params : int list, cons : (int * string * Types.ty option) list}) =
    (extras := Unknown;
     datatypes := IntMap.insert (!datatypes, stamp,
                                 {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map FromElab a)) cons}))
  fun bindDatatypeDirect (stamp : int, {params, cons} : {params : int list, cons : (int * string * ty option) list}) =
    (extras := Unknown;
     datatypes := IntMap.insert (!datatypes, stamp,
                                 {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map Direct a)) cons}))
  fun bindRealization (stamp : int, fcn : Types.tyfcn) = IntTable.insert (realizations, stamp, fcn)

  (* bool and list, which no declaration makes *)
  val () =
    let
      val a = Types.freshTvar (Types.genericLevel, Types.KPlain, false)
      val aid = case a of Types.TVar (ref (Types.Unbound {id, ...})) => id | _ => 0
    in
      bindDatatype (#stamp Types.boolTycon, {params = [], cons = [(0, "false", NONE), (1, "true", NONE)]});
      bindDatatype (#stamp Types.listTycon,
                    {params = [aid], cons = [(0, "nil", NONE), (1, "::", SOME (Types.tupleTy [a, Types.listTy a]))]})
    end

  (* ---- from the elaborator's types ---- *)

  (* the generic variables an elaborator's type names, and the datatypes,
     added to acc *)
  fun scan (t : Types.ty, acc as (gens, stamps) : unit IntMap.map * unit IntMap.map) =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        if level = Types.genericLevel then (IntMap.insert (gens, id, ()), stamps) else acc
    | Types.TVar (ref (Types.Bound t)) => scan (t, acc)
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => scan (Types.TCon (c', args), acc)
         | SOME (Types.TAbbrev (params, body)) => scan (Types.substitute (params, args, body), acc)
         | NONE => List.foldl scan (gens, IntMap.insert (stamps, #stamp c, ())) args)
    | Types.TRecord fields => List.foldl (fn ((_, t), acc) => scan (t, acc)) acc fields
    | Types.TArrow (a, b) => scan (b, scan (a, acc))

  (* whether an elaborator's type names a generic variable not in params *)
  fun namesOther (params : int list) (t : Types.ty) : bool =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        level = Types.genericLevel andalso not (List.exists (fn p => p = id) params)
    | Types.TVar (ref (Types.Bound t)) => namesOther params t
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => namesOther params (Types.TCon (c', args))
         | SOME (Types.TAbbrev (ps, body)) => namesOther params (Types.substitute (ps, args, body))
         | NONE => List.exists (namesOther params) args)
    | Types.TRecord fields => List.exists (namesOther params o #2) fields
    | Types.TArrow (a, b) => namesOther params a orelse namesOther params b

  (* each datatype's extra parameters (extras), where it has some *)
  fun workOutExtras () : int list IntMap.map =
    let
      (* each datatype of the elaborator's: the variables its
         constructors name that are not its parameters, and the
         datatypes they name *)
      val direct =
        IntMap.map (fn {params, cons} =>
                      let
                        val (gens, stamps) =
                          List.foldl (fn ((_, _, SOME (FromElab t)), acc) => scan (t, acc) | (_, acc) => acc)
                                     (IntMap.empty, IntMap.empty) cons
                      in
                        (IntMap.filteri (fn (g, ()) => not (List.exists (fn p => p = g) params)) gens,
                         IntMap.listKeys stamps)
                      end)
                   (!datatypes)
      (* and those of the datatypes they name, until no more come *)
      fun round m =
        let
          val m' =
            IntMap.mapi (fn (s, gens) =>
                           case IntMap.find (direct, s) of
                             SOME (_, named) =>
                               List.foldl (fn (n, g) =>
                                             case IntMap.find (m, n) of
                                               SOME g' => IntMap.unionWith #1 (g, g')
                                             | NONE => g)
                                          gens named
                           | NONE => gens)
                        m
        in
          if IntMap.foldl (fn (g, n) => n + IntMap.numItems g) 0 m'
             = IntMap.foldl (fn (g, n) => n + IntMap.numItems g) 0 m
          then m else round m'
        end
    in
      IntMap.map (fn gs => IntMap.listKeys gs)
                 (IntMap.filteri (fn (_, gs) => not (IntMap.isEmpty gs)) (round (IntMap.map #1 direct)))
    end

  (* the table, worked out only where some datatype names a variable not
     among its parameters *)
  fun computeExtras () : extras =
    let
      val some =
        IntMap.foldl (fn ({params, cons}, any) =>
                        any orelse List.exists (fn (_, _, SOME (FromElab t)) => namesOther params t | _ => false) cons)
                     false (!datatypes)
      val e = if not some then NoExtras
              else let val m = workOutExtras () in if IntMap.isEmpty m then NoExtras else Extras m end
    in
      extras := e; e
    end

  fun extrasOf (stamp : int) : int list =
    case (case !extras of Unknown => computeExtras () | e => e) of
      NoExtras => []
    | Extras m => (case IntMap.find (m, stamp) of SOME l => l | NONE => [])
    | Unknown => []

  fun fromTypes (t : Types.ty) : ty =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        if level = Types.genericLevel then Gen id else Var id
    | Types.TVar (ref (Types.Bound t)) => fromTypes t
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => fromTypes (Types.TCon (c', args))
         | SOME (Types.TAbbrev (params, body)) => fromTypes (Types.substitute (params, args, body))
         | NONE =>
             (case !extras of
                NoExtras => Con (#stamp c, #name c, List.map fromTypes args)
              | _ =>
                  (case extrasOf (#stamp c) of
                     [] => Con (#stamp c, #name c, List.map fromTypes args)
                   | extra => Con (#stamp c, #name c, List.map fromTypes args @ List.map Gen extra))))
    | Types.TRecord fields => Tuple (List.map (fromTypes o #2) fields)
    | Types.TArrow (a, b) => Arrow (fromTypes a, fromTypes b)

  fun argOf (FromElab t) = fromTypes t
    | argOf (Direct t) = t

  (* A datatype's parameters, its extra ones after its own, and its
     constructors' arguments as types. *)
  fun paramsOf (stamp : int, params : int list) =
    case !extras of
      NoExtras => params
    | _ => (case extrasOf stamp of [] => params | extra => params @ extra)
  fun datatypeOf (stamp : int) : {params : int list, cons : (int * string * ty option) list} option =
    case IntMap.find (!datatypes, stamp) of
      NONE => NONE
    | SOME {params, cons} =>
        SOME {params = paramsOf (stamp, params), cons = List.map (fn (t, n, a) => (t, n, Option.map argOf a)) cons}

  (* ---- the types the translation makes ---- *)

  val int = Con (#stamp Types.intTycon, "int", [])
  val int64 = Con (#stamp Types.int64Tycon, #name Types.int64Tycon, [])
  val word64 = Con (#stamp Types.word64Tycon, #name Types.word64Tycon, [])
  val bool = Con (#stamp Types.boolTycon, "bool", [])
  val string = Con (#stamp Types.stringTycon, "string", [])
  val exn = Con (#stamp Types.exnTycon, "exn", [])
  val unit = Tuple []
  fun list t = Con (#stamp Types.listTycon, "list", [t])
  fun refTy t = Con (#stamp Types.refTycon, "ref", [t])

  (* ---- comparing and instantiating ---- *)

  fun equal (a : ty, b : ty) : bool =
    case (a, b) of
      (Gen x, Gen y) => x = y
    | (Var x, Var y) => x = y
    | (Con (s, _, xs), Con (t, _, ys)) => s = t andalso ListPair.allEq equal (xs, ys)
    | (Tuple xs, Tuple ys) => ListPair.allEq equal (xs, ys)
    | (Arrow (x1, x2), Arrow (y1, y2)) => equal (x1, y1) andalso equal (x2, y2)
    | (ExnCon, ExnCon) => true
    | _ => false

  (* The generic variables of a scheme made the types an instance gives
     them: SOME the substitution where the instance is one, NONE where it is
     not. *)
  fun match (scheme : ty, inst : ty) : ty IntMap.map option =
    let
      exception No
      fun go (Gen x, t, s) =
            (case IntMap.find (s, x) of
               SOME t' => if equal (t, t') then s else raise No
             | NONE => IntMap.insert (s, x, t))
        | go (Con (a, _, xs), Con (b, _, ys), s) =
            if a = b andalso List.length xs = List.length ys then ListPair.foldl (fn (x, y, s) => go (x, y, s)) s (xs, ys)
            else raise No
        | go (Tuple xs, Tuple ys, s) =
            if List.length xs = List.length ys then ListPair.foldl (fn (x, y, s) => go (x, y, s)) s (xs, ys)
            else raise No
        | go (Arrow (x1, x2), Arrow (y1, y2), s) = go (x2, y2, go (x1, y1, s))
        | go (x, y, s) = if equal (x, y) then s else raise No
    in
      SOME (go (scheme, inst, IntMap.empty)) handle No => NONE
    end

  fun subst (s : ty IntMap.map) (t : ty) : ty =
    case t of
      Gen x => (case IntMap.find (s, x) of SOME t' => t' | NONE => t)
    | Con (a, n, xs) => Con (a, n, List.map (subst s) xs)
    | Tuple xs => Tuple (List.map (subst s) xs)
    | Arrow (a, b) => Arrow (subst s a, subst s b)
    | _ => t

  (* The argument of the constructor with a tag, of a datatype at the
     arguments given, where the datatype is one and it has that constructor:
     SOME NONE for a nullary one. *)
  fun conArg (stamp : int, args : ty list, tag : int) : ty option option =
    case IntMap.find (!datatypes, stamp) of
      NONE => NONE
    | SOME {params, cons} =>
        (case List.find (fn (t, _, _) => t = tag) cons of
           NONE => NONE
         | SOME (_, _, arg) =>
             let val params = paramsOf (stamp, params)
             in
               if List.length params <> List.length args then NONE
               else
                 let
                   val s = ListPair.foldl (fn (p, a, s) => IntMap.insert (s, p, a)) IntMap.empty (params, args)
                 in
                   SOME (Option.map (subst s o argOf) arg)
                 end
             end)

  (* A type as text, a variable written as the functions given say. *)
  fun format (gen : int -> string, var : int -> string) (t : ty) : string =
    let
      fun go t =
        case t of
          Gen x => gen x
        | Var x => var x
        | Con (_, n, []) => n
        | Con (_, n, [a]) => atomic a ^ " " ^ n
        | Con (_, n, xs) => "(" ^ String.concatWith ", " (List.map go xs) ^ ") " ^ n
        | Tuple [] => "unit"
        | Tuple [x] => "{" ^ go x ^ "}"         (* a record of one field *)
        | Tuple xs => String.concatWith " * " (List.map atomic xs)
        | Arrow (a, b) => atomic a ^ " -> " ^ go b
        | ExnCon => "exncon"
      and atomic t =
        case t of
          Tuple (_ :: _ :: _) => "(" ^ go t ^ ")"
        | Arrow _ => "(" ^ go t ^ ")"
        | _ => go t
    in go t end

  (* by the elaborator's ids, for messages *)
  val toString = format (fn x => "'a" ^ Int.toString x, fn x => "'_" ^ Int.toString x)
end
