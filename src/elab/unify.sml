(* Unification, generalization and instantiation. *)
structure Unify =
struct
  open Types

  exception Unify of string

  fun kindName KPlain = "type variable"
    | kindName (KOverload names) = "overloaded operator type (" ^ String.concatWith "/" names ^ ")"
    | kindName (KFlex _) = "flexible record type"

  (* Occurs check and level adjustment before binding variable r (at level lvl) to t. *)
  fun occursAdjust (r : tvar ref, lvl : int, t : ty) : unit =
    case prune t of
      TVar r' =>
        if r = r' then raise Unify "circular type"
        else
          (case !r' of
             Unbound {id, level, kind, eq} =>
               (if level > lvl then r' := Unbound {id = id, level = lvl, kind = kind, eq = eq} else ();
                case kind of
                  KFlex fields => List.app (fn (_, t) => occursAdjust (r, lvl, t)) fields
                | _ => ())
           | Bound _ => ())
    | TCon (_, args) => List.app (fn a => occursAdjust (r, lvl, a)) args
    | TRecord fields => List.app (fn (_, a) => occursAdjust (r, lvl, a)) fields
    | TArrow (a, b) => (occursAdjust (r, lvl, a); occursAdjust (r, lvl, b))

  fun levelOf (r : tvar ref) = case !r of Unbound {level, ...} => level | Bound _ => genericLevel

  fun unify (t1 : ty, t2 : ty) : unit =
    let
      val t1 = prune t1
      val t2 = prune t2
    in
      case (t1, t2) of
        (TVar r1, TVar r2) => if r1 = r2 then () else bindVar (r1, t2)
      | (TVar r, t) => bindVar (r, t)
      | (t, TVar r) => bindVar (r, t)
      | (TCon (c1, a1), TCon (c2, a2)) =>
          if sameTycon (c1, c2) then ListPair.app unify (a1, a2)
          else raise Unify ("type constructor mismatch: " ^ #name c1 ^ " vs " ^ #name c2)
      | (TRecord f1, TRecord f2) =>
          let
            fun go ([], []) = ()
              | go ((l1, a) :: r1, (l2, b) :: r2) =
                if l1 = l2 then (unify (a, b); go (r1, r2))
                else raise Unify ("record label mismatch: " ^ l1 ^ " vs " ^ l2)
              | go _ = raise Unify "records have different numbers of fields"
          in go (f1, f2) end
      | (TArrow (a1, b1), TArrow (a2, b2)) => (unify (a1, a2); unify (b1, b2))
      | _ => raise Unify "type mismatch"
    end

  (* Bind unbound variable r to t, respecting its kind. *)
  and bindVar (r : tvar ref, t : ty) : unit =
    case !r of
      Bound _ => Error.bug "bindVar on bound variable"
    | Unbound {id, level, kind, eq} =>
      (case kind of
         KPlain => (occursAdjust (r, level, t); r := Bound t)
       | KOverload names =>
           (case t of
              TVar r2 =>
                (case !r2 of
                   Unbound {kind = KPlain, ...} => bindVar (r2, TVar r)
                 | Unbound {id = id2, level = level2, kind = KOverload names2, eq = eq2} =>
                     let
                       val common = List.filter (fn n => List.exists (fn m => m = n) names2) names
                     in
                       case common of
                         [] => raise Unify ("no common type for overloaded operators (" ^
                                            String.concatWith "/" names ^ " vs " ^ String.concatWith "/" names2 ^ ")")
                       | _ =>
                         (r2 := Unbound {id = id2, level = Int.min (level, level2), kind = KOverload common, eq = eq orelse eq2};
                          r := Bound (TVar r2))
                     end
                 | Unbound {kind = KFlex _, ...} => raise Unify "overloaded operator applied to a record"
                 | Bound _ => Error.bug "bindVar: pruned variable is bound")
            | TCon (c, []) =>
                if List.exists (fn n => n = #name c) names then r := Bound t
                else raise Unify ("overloaded operator not defined at type " ^ #name c)
            | _ => raise Unify ("overloaded operator used at type " ^ toString t))
       | KFlex fields =>
           (case t of
              TVar r2 =>
                (case !r2 of
                   Unbound {kind = KPlain, ...} => bindVar (r2, TVar r)
                 | Unbound {id = id2, level = level2, kind = KFlex fields2, eq = eq2} =>
                     let
                       (* unify common fields, merge the rest *)
                       fun merge ([], f2) = f2
                         | merge ((l, a) :: rest, f2) =
                           case List.find (fn (l2, _) => l2 = l) f2 of
                             SOME (_, b) => (unify (a, b); merge (rest, f2))
                           | NONE => merge (rest, sortFields ((l, a) :: f2))
                       val merged = merge (fields, fields2)
                       val lvl = Int.min (level, level2)
                       val r3 = freshTvar (lvl, KFlex merged, eq orelse eq2)
                     in
                       List.app (fn (_, a) => occursAdjust (r, lvl, a)) merged;
                       r := Bound r3; r2 := Bound r3
                     end
                 | Unbound {kind = KOverload _, ...} => raise Unify "record used with an overloaded operator"
                 | Bound _ => Error.bug "bindVar: pruned variable is bound")
            | TRecord fields2 =>
                (List.app (fn (l, a) =>
                             case List.find (fn (l2, _) => l2 = l) fields2 of
                               SOME (_, b) => unify (a, b)
                             | NONE => raise Unify ("record has no field '" ^ l ^ "'")) fields;
                 occursAdjust (r, level, t);
                 r := Bound t)
            | _ => raise Unify ("record type expected but found " ^ toString t)))

  (* Mark variables above `level` as generic (let-polymorphism). Overloaded
     variables and flexible records are never generalized. *)
  fun generalize (level : int, t : ty) : unit =
    case prune t of
      TVar r =>
        (case !r of
           Unbound {id, level = l, kind = KPlain, eq} =>
             if l > level then r := Unbound {id = id, level = genericLevel, kind = KPlain, eq = eq} else ()
         | _ => ())
    | TCon (_, args) => List.app (fn a => generalize (level, a)) args
    | TRecord fields => List.app (fn (_, a) => generalize (level, a)) fields
    | TArrow (a, b) => (generalize (level, a); generalize (level, b))

  (* Value restriction: keep variables monomorphic by lowering them to `level`. *)
  fun lowerLevels (level : int, t : ty) : unit =
    case prune t of
      TVar r =>
        (case !r of
           Unbound {id, level = l, kind, eq} =>
             if l > level andalso l <> genericLevel then r := Unbound {id = id, level = level, kind = kind, eq = eq} else ()
         | _ => ())
    | TCon (_, args) => List.app (fn a => lowerLevels (level, a)) args
    | TRecord fields => List.app (fn (_, a) => lowerLevels (level, a)) fields
    | TArrow (a, b) => (lowerLevels (level, a); lowerLevels (level, b))

  (* Copy a scheme replacing generic variables with fresh ones at `level`. *)
  fun instantiate (level : int, scheme : scheme) : ty =
    let
      val memo : (int * ty) list ref = ref []
      fun copy t =
        case prune t of
          t as TVar r =>
            (case !r of
               Unbound {id, level = l, kind, eq} =>
                 if l = genericLevel then
                   (case List.find (fn (i, _) => i = id) (!memo) of
                      SOME (_, t') => t'
                    | NONE =>
                      let val t' = freshTvar (level, kind, eq)
                      in memo := (id, t') :: !memo; t' end)
                 else t
             | Bound _ => Error.bug "instantiate: pruned variable is bound")
        | TCon (c, args) => TCon (c, List.map copy args)
        | TRecord fields => TRecord (List.map (fn (l, a) => (l, copy a)) fields)
        | TArrow (a, b) => TArrow (copy a, copy b)
    in copy scheme end

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
end
