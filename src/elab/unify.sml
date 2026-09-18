(* Unification, generalization and instantiation. *)
structure Unify =
struct
  open Types

  exception Unify of string

  fun kindName KPlain = "type variable"
    | kindName (KRigid n) = "explicit type variable " ^ n
    | kindName (KOverload names) = "overloaded operator type (" ^ String.concatWith "/" names ^ ")"
    | kindName (KFlex _) = "flexible record type"

  (* Flexible record variables created by instantiation are reported here so
     that the elaborator can check that they get resolved. *)
  val flexHook : (tvar ref -> unit) ref = ref (fn _ => ())

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
                  KFlex (fields, _) => List.app (fn (_, t) => occursAdjust (r, lvl, t)) fields
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
      fun isRigid r = case !r of Unbound {kind = KRigid _, ...} => true | _ => false
    in
      case (t1, t2) of
        (TVar r1, TVar r2) =>
          if r1 = r2 then ()
          else if isRigid r1 andalso isRigid r2 then
            raise Unify ("the explicit type variables " ^ toString t1 ^ " and " ^ toString t2 ^ " are distinct")
          else if isRigid r1 then bindVar (r2, t1)
          else bindVar (r1, t2)
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

  (* Equality attribute (Section 4.4): make t admit equality by marking its
     variables, and reject types that cannot. *)
  and makeEq (t : ty) : unit =
    case prune t of
      TVar r =>
        (case !r of
           Unbound {id, level, kind, eq} =>
             if eq then ()
             else
               (case kind of
                  KOverload names =>
                    (case List.filter (fn n => n <> "real") names of
                       [] => raise Unify "overloaded operator used at a type that does not admit equality"
                     | names' => r := Unbound {id = id, level = level, kind = KOverload names', eq = true})
                | KFlex (fields, _) =>
                    (r := Unbound {id = id, level = level, kind = kind, eq = true};
                     List.app (fn (_, a) => makeEq a) fields)
                | KPlain => r := Unbound {id = id, level = level, kind = kind, eq = true}
                | KRigid n => raise Unify ("the explicit type variable " ^ n ^ " does not admit equality"))
         | Bound _ => Error.bug "makeEq: pruned variable is bound")
    | TCon (c, args) =>
        if sameTycon (c, refTycon) orelse sameTycon (c, arrayTycon) then ()
        else if not (#eq c) then raise Unify ("type " ^ toString (TCon (c, args)) ^ " does not admit equality")
        else List.app makeEq args
    | TRecord fields => List.app (fn (_, a) => makeEq a) fields
    | TArrow _ => raise Unify "function types do not admit equality"

  (* Bind unbound variable r to t, respecting its kind and equality attribute. *)
  and bindVar (r : tvar ref, t : ty) : unit =
    case !r of
      Bound _ => Error.bug "bindVar on bound variable"
    | Unbound {id, level, kind, eq} =>
      (if eq then makeEq t else ();
       case kind of
         KPlain => (occursAdjust (r, level, t); r := Bound t)
       | KRigid n =>
           (case t of
              TVar r2 => (case !r2 of
                            Unbound {kind = KPlain, ...} => bindVar (r2, TVar r)
                          | _ => raise Unify ("the explicit type variable " ^ n ^ " cannot be instantiated"))
            | _ => raise Unify ("the explicit type variable " ^ n ^ " cannot be instantiated to " ^ toString t))
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
                 | Unbound {kind = KRigid n, ...} => raise Unify ("overloaded operator used at the explicit type variable " ^ n)
                 | Bound _ => Error.bug "bindVar: pruned variable is bound")
            | TCon (c, []) =>
                let
                  (* one admissible kind: the variable stands for a constant or
                     for operands of that kind, and reads like its default type *)
                  fun mismatch () =
                    case names of
                      [kind] => raise Unify ("type constructor mismatch: " ^ kind ^ " vs " ^ #name c)
                    | _ => raise Unify ("overloaded operator not defined at type " ^ toString t)
                in
                  case Overload.kindOf c of
                    SOME kind => if List.exists (fn n => n = kind) names then r := Bound t else mismatch ()
                  | NONE => mismatch ()
                end
            | _ => raise Unify ("overloaded operator used at type " ^ toString t))
       | KFlex (fields, group) =>
           (case t of
              TVar r2 =>
                (case !r2 of
                   Unbound {kind = KPlain, ...} => bindVar (r2, TVar r)
                 | Unbound {id = id2, level = level2, kind = KFlex (fields2, group2), eq = eq2} =>
                     let
                       (* unify common fields, merge the rest; the two groups become one *)
                       fun merge ([], f2) = f2
                         | merge ((l, a) :: rest, f2) =
                           case List.find (fn (l2, _) => l2 = l) f2 of
                             SOME (_, b) => (unify (a, b); merge (rest, f2))
                           | NONE => merge (rest, sortFields ((l, a) :: f2))
                       val merged = merge (fields, fields2)
                       val lvl = Int.min (level, level2)
                       val members = !group @ (if group = group2 then [] else !group2)
                       val group3 : flexgroup = ref members
                       val r3 = freshFlexIn (lvl, merged, eq orelse eq2, group3)
                     in
                       List.app (fn (_, a) => occursAdjust (r, lvl, a)) merged;
                       r := Bound r3; r2 := Bound r3;
                       (* redirect the other members to the merged group *)
                       List.app (fn m =>
                                    case !m of
                                      Unbound {id, level, kind = KFlex (fs, _), eq} =>
                                        m := Unbound {id = id, level = level, kind = KFlex (fs, group3), eq = eq}
                                    | _ => ()) members
                     end
                 | Unbound {kind = KOverload _, ...} => raise Unify "record used with an overloaded operator"
                 | Unbound {kind = KRigid n, ...} => raise Unify ("record type expected but found the explicit type variable " ^ n)
                 | Bound _ => Error.bug "bindVar: pruned variable is bound")
            | TRecord fields2 =>
                (List.app (fn (l, a) =>
                             case List.find (fn (l2, _) => l2 = l) fields2 of
                               SOME (_, b) => unify (a, b)
                             | NONE => raise Unify ("record has no field '" ^ l ^ "'")) fields;
                 occursAdjust (r, level, t);
                 r := Bound t;
                 (* the other variables of the group now know their labels too *)
                 List.app (fn m =>
                              case !m of
                                Unbound {level = lm, kind = KFlex (fs, _), ...} =>
                                  let
                                    val record =
                                      TRecord (List.map (fn (l, _) =>
                                                            case List.find (fn (l', _) => l' = l) fs of
                                                              SOME (_, a) => (l, a)
                                                            | NONE => (l, freshTvar (lm, KPlain, false))) fields2)
                                  in bindVar (m, record) end
                              | _ => ()) (!group))
            | _ => raise Unify ("record type expected but found " ^ toString t)))

  (* Value restriction: keep variables monomorphic by lowering them to `level`. *)
  fun lowerLevels (level : int, t : ty) : unit =
    case prune t of
      TVar r =>
        (case !r of
           Unbound {id, level = l, kind, eq} =>
             (if l > level andalso l <> genericLevel then r := Unbound {id = id, level = level, kind = kind, eq = eq} else ();
              case kind of
                KFlex (fields, _) => List.app (fn (_, a) => lowerLevels (level, a)) fields
              | _ => ())
         | _ => ())
    | TCon (_, args) => List.app (fn a => lowerLevels (level, a)) args
    | TRecord fields => List.app (fn (_, a) => lowerLevels (level, a)) fields
    | TArrow (a, b) => (lowerLevels (level, a); lowerLevels (level, b))

  (* Mark variables above `level` as generic (let-polymorphism). Overloaded
     variables are never generalized. A flexible record variable is, together
     with its field types; its instances stay linked to it through the group,
     so the record's labels are shared by all uses once determined. *)
  fun generalize (level : int, t : ty) : unit =
    case prune t of
      TVar r =>
        (case !r of
           Unbound {id, level = l, kind = KPlain, eq} =>
             if l > level then r := Unbound {id = id, level = genericLevel, kind = KPlain, eq = eq} else ()
         | Unbound {id, level = l, kind = kind as KRigid _, eq} =>
             if l > level then r := Unbound {id = id, level = genericLevel, kind = kind, eq = eq} else ()
         | Unbound {id, level = l, kind = kind as KFlex (fields, _), eq} =>
             if l > level then
               (r := Unbound {id = id, level = genericLevel, kind = kind, eq = eq};
                List.app (fn (_, a) => generalize (level, a)) fields)
             else ()
         | _ => ())
    | TCon (_, args) => List.app (fn a => generalize (level, a)) args
    | TRecord fields => List.app (fn (_, a) => generalize (level, a)) fields
    | TArrow (a, b) => (generalize (level, a); generalize (level, b))

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
                      let
                        val t' =
                          case kind of
                            KRigid _ => freshTvar (level, KPlain, eq)
                          | KFlex (fields, group) =>
                              let val t' = freshFlexIn (level, List.map (fn (l, a) => (l, copy a)) fields, eq, group)
                              in (case t' of TVar r' => (!flexHook) r' | _ => ()); t' end
                          | k => freshTvar (level, k, eq)
                      in memo := (id, t') :: !memo; t' end)
                 else t
             | Bound _ => Error.bug "instantiate: pruned variable is bound")
        | TCon (c, args) => TCon (c, List.map copy args)
        | TRecord fields => TRecord (List.map (fn (l, a) => (l, copy a)) fields)
        | TArrow (a, b) => TArrow (copy a, copy b)
    in copy scheme end
end
