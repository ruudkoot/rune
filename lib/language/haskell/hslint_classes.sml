(* The classes and instances of HsLint's second inference (the haskell98
   roadmap's M16, D54), and what Typing Haskell in Haskell does with them:
   entailment by superclasses and by instances (7.3), context reduction to
   head normal form (7.4), and the ambiguities, candidates and defaults of
   4.3.4 (11.5.1), with `split` (11.5).

   The environment is the program's: every class and instance a program
   declares or derives is visible in all of it (4.3.2, 5.4). It is set
   once a program's declarations are read, by HsLintEnv. *)
structure HsLintClasses =
struct
  structure T = HsLintTypes
  structure M = HsStringMap

  (* A class: its superclasses, the kind of its variable, and whether it
     is defined in the Prelude or a library of the Report, a standard
     class of 4.3.4. *)
  type class = {id : T.id, kind : T.kind, supers : T.id list, std : bool}

  (* An instance: its head and its context over the generic variables
     0 to arity - 1, where it was declared, and whether it was derived. *)
  type inst = {head : T.pred, context : T.pred list, arity : int, span : HsSource.span, derived : bool}

  val classes : class M.map ref = ref M.empty
  val insts : inst list M.map ref = ref M.empty

  (* the instances added since the instances were set, by `reset` or a
     restore of HsLintEnv's, the latest first: those of the modules read
     since, which a unit's part and its checks read, beside those of the
     units before it, which they do not (build-cache-issues.md, issue 39) *)
  val added : inst list ref = ref []

  (* each instance by its class and its type constructor, `CLASS\tTYCON`:
     one in a program (cls.inst.once), found where an instance is wanted,
     and not by trying every instance of the class, which made a unit after
     n instances of Eq cost as n (build-cache-issues.md, issue 39) *)
  val heads : inst M.map ref = ref M.empty
  fun headKey (c, tc) = T.idKey c ^ "\t" ^ T.idKey tc
  fun headOf ({head = T.IsIn (c, h), ...} : inst) =
    case T.spine h of
      (T.TCon {id, ...}, _) => SOME (headKey (c, id))
    | _ => NONE
  fun headsOf (is : inst list M.map) : inst M.map =
    M.foldl (fn (_, is, m) => List.foldl (fn (i, m) => case headOf i of SOME k => M.insert (m, k, i) | NONE => m) m is)
      M.empty is

  (* the Prelude's `Num`, which makes a class numeric (4.3.4) *)
  val numId : T.id option ref = ref NONE

  fun reset () = (classes := M.empty; insts := M.empty; added := []; heads := M.empty; numId := NONE)

  fun findClass c = M.find (!classes, T.idKey c)
  fun supers c = case findClass c of SOME {supers, ...} => supers | NONE => []
  fun instsOf c = getOpt (M.find (!insts, T.idKey c), [])

  fun addInst (i as {head = T.IsIn (c, _), ...} : inst) =
    (insts := M.insert (!insts, T.idKey c, instsOf c @ [i]); added := i :: !added;
     case headOf i of SOME k => heads := M.insert (!heads, k, i) | NONE => ())

  (* of the instances added, those `take` takes, by class, each class's in
     the order of its instances: what a fold over every class's instances
     meets of them where `take` takes none of those set before *)
  fun addedBy (take : inst -> bool) : inst list M.map =
    List.foldl (fn (i as {head = T.IsIn (c, _), ...} : inst, m) =>
                  if take i then M.insert (m, T.idKey c, getOpt (M.find (m, T.idKey c), []) @ [i]) else m)
      M.empty (List.rev (!added))

  (* every class `c` is a subclass of, `c` among them *)
  fun closure c =
    let
      fun go (c, seen) =
        if List.exists (fn d => T.idEq (c, d)) seen then seen
        else List.foldl go (c :: seen) (supers c)
    in
      List.rev (go (c, []))
    end

  (* `Num` or a subclass of `Num` (4.3.4) *)
  fun isNumeric c =
    case !numId of
      SOME n => List.exists (fn d => T.idEq (d, n)) (closure c)
    | NONE => false

  fun isStd c = case findClass c of SOME {std, ...} => std | NONE => false

  (* ---- entailment (7.3) ---- *)

  fun bySuper (p as T.IsIn (c, t)) = p :: List.concat (List.map (fn c' => bySuper (T.IsIn (c', t))) (supers c))

  (* the context of the instance that `p` is an instance of, if any *)
  (* 5.4: whether an instance is in scope where the inference is, a chain
     of imports leading from there to its module (R26); HsLintInfer sets
     it, every instance in scope while it does not *)
  val inScope : (inst -> bool) ref = ref (fn _ => true)

  fun byInst (T.IsIn (c, t)) =
    let
      fun try [] = NONE
        | try ((i as {head = T.IsIn (_, h), context, arity, ...}) :: rest : inst list) =
            let val slots = Array.array (arity, NONE)
            in
              if !inScope i andalso T.matchGen (slots, h, t) then
                let val ts = Vector.tabulate (arity, fn i => case Array.sub (slots, i) of SOME u => u | NONE => T.newTVar T.Star)
                in SOME (List.map (T.instPred ts) context) end
              else try rest
            end
    in
      (* every instance's head is a type constructor's (cls.inst.reject.var):
         the one instance of the class at that of `t`, if any *)
      case T.spine t of
        (T.TCon {id, ...}, _) => try (case M.find (!heads, headKey (c, id)) of SOME i => [i] | NONE => [])
      | _ => try (instsOf c)
    end

  fun entail ps p =
    List.exists (fn q => List.exists (fn r => T.predEq (r, p)) (bySuper q)) ps
    orelse (case byInst p of NONE => false | SOME qs => List.all (entail ps) qs)

  (* ---- context reduction (7.4) ---- *)

  fun inHnf (T.IsIn (_, t)) = case T.spine t of (T.TVar _, _) => true | _ => false

  (* a predicate that no instance holds of: a static error (4.5.3) *)
  exception NoInstance of T.pred

  fun toHnf p =
    if inHnf p then [p]
    else case byInst p of
           NONE => raise NoInstance (T.zonkPred p)
         | SOME ps => toHnfs ps
  and toHnfs ps = List.concat (List.map toHnf ps)

  fun simplify ps =
    let
      fun loop (rs, []) = rs
        | loop (rs, p :: ps) = if entail (rs @ ps) p then loop (rs, ps) else loop (p :: rs, ps)
    in
      loop ([], ps)
    end

  fun reduce ps = simplify (toHnfs (List.map T.zonkPred ps))

  (* ---- ambiguity and defaults (11.5.1) ---- *)

  (* an ambiguous variable with no default: the variable and its
     predicates *)
  exception Ambiguous of T.tyvar * T.pred list

  fun mentions (v, T.IsIn (_, t)) = T.occurs (v, t)

  fun ambiguities (vs : T.tyvar list, ps) =
    List.map (fn v => (v, List.filter (fn p => mentions (v, p)) ps))
      (List.filter (fn v => not (List.exists (fn w => T.tvEq (v, w)) vs)) (T.predTvs ps))

  (* the defaults that may resolve an ambiguity (4.3.4): each predicate
     on the variable alone, one class numeric, all standard, and each
     class held by the type *)
  fun candidates (defaults : T.ty list, (v, qs)) =
    let
      val is = List.map (fn T.IsIn (i, _) => i) qs
      val ts = List.map (fn T.IsIn (_, t) => t) qs
    in
      if List.all (fn t => case T.prune t of T.TVar w => T.tvEq (v, w) | _ => false) ts
         andalso List.exists isNumeric is andalso List.all isStd is
      then List.filter (fn t' => List.all (fn i => entail [] (T.IsIn (i, t'))) is) defaults
      else []
    end

  (* `withDefaults (defaults, vs, ps)`: each ambiguity of `ps` with the
     default chosen for it, the first candidate.

     Raises: `Ambiguous` for one with no candidate. *)
  fun withDefaults (defaults, vs, ps) =
    List.map (fn a as (v, qs) =>
                case candidates (defaults, a) of
                  t :: _ => (v, qs, t)
                | [] => raise Ambiguous (v, List.map T.zonkPred qs))
      (ambiguities (vs, ps))

  (* `split (defaults, fs, gs, ps)`: the predicates reduced, then parted
     into those deferred, on fixed variables alone, and those retained,
     less those a default resolves, which are returned with their choice
     (11.5) *)
  fun split (defaults, fs : T.tyvar list, gs : T.tyvar list, ps) =
    let
      val ps' = reduce ps
      fun fixed p = List.all (fn v => List.exists (fn w => T.tvEq (v, w)) fs) (T.predTvs [p])
      val ds = List.filter fixed ps'
      val rs = List.filter (not o fixed) ps'
      val chosen = withDefaults (defaults, fs @ gs, rs)
      fun defaulted p = List.exists (fn (_, qs, _) => List.exists (fn q => T.predEq (p, q)) qs) chosen
    in
      (ds, List.filter (not o defaulted) rs, chosen)
    end
end
