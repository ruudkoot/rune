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

  fun bindVar (stamp : int, t : Types.ty) = IntTable.insert (binders, stamp, t)
  fun bindExn (stamp : int, arg : Types.ty option) = IntTable.insert (exnArgs, stamp, arg)
  fun bindDatatype (stamp : int, {params, cons} : {params : int list, cons : (int * string * Types.ty option) list}) =
    datatypes := IntMap.insert (!datatypes, stamp,
                                {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map FromElab a)) cons})
  fun bindDatatypeDirect (stamp : int, {params, cons} : {params : int list, cons : (int * string * ty option) list}) =
    datatypes := IntMap.insert (!datatypes, stamp,
                                {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map Direct a)) cons})
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

  fun fromTypes (t : Types.ty) : ty =
    case Types.prune t of
      Types.TVar (ref (Types.Unbound {id, level, ...})) =>
        if level = Types.genericLevel then Gen id else Var id
    | Types.TVar (ref (Types.Bound t)) => fromTypes t
    | Types.TCon (c, args) =>
        (case IntTable.find (realizations, #stamp c) of
           SOME (Types.TName c') => fromTypes (Types.TCon (c', args))
         | SOME (Types.TAbbrev (params, body)) => fromTypes (Types.substitute (params, args, body))
         | NONE => Con (#stamp c, #name c, List.map fromTypes args))
    | Types.TRecord fields => Tuple (List.map (fromTypes o #2) fields)
    | Types.TArrow (a, b) => Arrow (fromTypes a, fromTypes b)

  fun argOf (FromElab t) = fromTypes t
    | argOf (Direct t) = t

  (* A datatype, its constructors' arguments as types. *)
  fun datatypeOf (stamp : int) : {params : int list, cons : (int * string * ty option) list} option =
    case IntMap.find (!datatypes, stamp) of
      NONE => NONE
    | SOME {params, cons} => SOME {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map argOf a)) cons}

  (* ---- the types the translation makes ---- *)

  val int = Con (#stamp Types.intTycon, "int", [])
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
             if List.length params <> List.length args then NONE
             else
               let
                 val s = ListPair.foldl (fn (p, a, s) => IntMap.insert (s, p, a)) IntMap.empty (params, args)
               in
                 SOME (Option.map (subst s o argOf) arg)
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
