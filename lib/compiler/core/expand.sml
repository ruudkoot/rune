(* The expansion (docs/plans/functors-units.md, M6; a prototype, under
   --functors=functions; docs/ir.md, Functors compiled once): Mid in which
   each functor is a function its applications call, given back the copies
   static interpretation makes, as far as a budget allows (D13).

   An application is a definition of the top level whose value is a call
   of a functor's function, after the place the type names its body
   substitutes (Translate.callExp: a cast of () to the type of the pairs
   name -> type, the parameter's type names realised by the argument and
   the body's datatypes by the application's instances). It is expanded
   where the function is defined in the program (in a build in units, the
   unit: D2 A):
   * the body is copied, its variables fresh, each type name the
     application substitutes made what it says, and each datatype the body
     declares over them made a fresh one (laid out from its realised
     types); a constructor whose layout the parameter leaves open is made
     and taken apart as the datatype it is (its descriptor's test folded);
   * the copy's declarations become definitions of the top level, as an
     application's are where static interpretation makes them: each
     binding, each group of functions, the value a join point gives the
     rest; what does not fit stays one definition of the record;
   * a slot read from a record whose value is known is that value, and a
     cast of it back through unit is the value cast from (at an instance of
     its scheme, for a polymorphic one): the casts the substitution made
     trivial go, in the copy and in what reads the application's result.
   The copies' applications are expanded in turn, all of them within
   --functor-budget Mid nodes a top-level application (0 expands nothing);
   past it, an application stays a call. An instance of a body's datatype
   is laid out from its realised types where no application left a call
   takes it (its descriptor was worked out from the body's layout, which
   such a one keeps). *)
structure Expand =
struct
  open Mid

  (* --functor-budget: the Mid nodes the copies of a top-level application,
     and of those in them, may hold *)
  val budget = ref 1000000
  val () = CompilerState.cellRoot ("Expand.budget", budget)
  (* how deep copies of applications in copies go *)
  val maxDepth = 64

  (* --pass-stats=expand: the applications expanded, those left calls,
     and the copies whose declarations did not all become definitions *)
  val stats = ref false
  val () = CompilerState.cellRoot ("Expand.stats", stats)
  val expanded = ref 0
  val () = CompilerState.cellRoot ("Expand.expanded", expanded)
  val kept = ref 0
  val () = CompilerState.cellRoot ("Expand.kept", kept)
  val partial = ref 0
  val () = CompilerState.cellRoot ("Expand.partial", partial)
  (* of those left calls, the ones past the budget; and the most a
     top-level application copied *)
  val overBudget = ref 0
  val () = CompilerState.cellRoot ("Expand.overBudget", overBudget)
  val most = ref 0
  val () = CompilerState.cellRoot ("Expand.most", most)

  fun bug msg = Error.bug ("expand: " ^ msg)
  fun fresh () = Elaborate.freshStamp ()

  (* Functors inlined across units (M6b; Elaborate.inlineFunctors): the
     functions of the marked functors a unit declares, as ToMid made them,
     by their globals, for its basis (UnitBasis.funcode); and those of the
     marked functors of the units before it, as their bases gave them, which
     a unit's applications of them expand as its own functors' *)
  val declaredBodies : fundef IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Expand.declaredBodies", declaredBodies, IntTable.copy)
  val imported : fundef IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Expand.imported", imported, IntTable.copy)
  (* and the names of the functions each binds (Translate.funNames, which
     each unit's translation begins empty), entered where it is copied *)
  val importedNames : (int * string) list IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Expand.importedNames", importedNames, IntTable.copy)

  (* Globals that are other globals (M6b): g whose definition, after the
     expansion, is the global h at the types g abstracts over -- what a copy
     binds to a primitive or to another's value (`val andb = Word.andb`),
     under an application's name. A unit's, for its basis (UnitBasis), and
     those of the units before it, as their bases gave them: a use of g in a
     later unit is one of h, as it is in the unit and in a whole program,
     where the expansion's aliases make it so; and a call of h, where h is
     bound to a primitive (Translate.primAliases), the primitive's (primCall) *)
  val globalAliases : int IntTable.table ref = ref (IntTable.table 64)
  val () = CompilerState.refRoot ("Expand.globalAliases", globalAliases, IntTable.copy)
  (* and functions of the top level that apply a primitive to their
     parameter (or its fields), as what a copy binds to a primitive is
     (`val length = size`): a unit's, for its basis, and those of the units
     before it; a call of one in a later unit is the primitive's, as a call
     of a name Translate.primAliases has is *)
  val primGlobals : string IntTable.table ref = ref (IntTable.table 64)
  val () = CompilerState.refRoot ("Expand.primGlobals", primGlobals, IntTable.copy)

  (* the primitive a function applies to its parameter, or to its fields
     in order, and gives back *)
  fun primOfFunction ({params, body, ...} : fundef) : string option =
    let
      fun under (Mark (_, e)) = under e
        | under e = e
      fun arity p = SOME (Translate.primArity p) handle Error.Bug _ => NONE
    in
      case params of
        [(x, _)] =>
          let
            fun go (e, fields) =
              case under e of
                Let (y, ([], _), Select (i, Var (x', [])), b) =>
                  if x' = x andalso i = List.length fields then go (b, fields @ [y]) else NONE
              | Return (Prim (p, _, args)) =>
                  (case (fields, args) of
                     ([], [Var (x', [])]) => if x' = x andalso arity p = SOME 1 then SOME p else NONE
                   | (_ :: _ :: _, _) =>
                       if List.length args = List.length fields
                          andalso ListPair.all (fn (Var (y, []), z) => y = z | _ => false) (args, fields)
                          andalso arity p = SOME (List.length fields)
                       then SOME p else NONE
                   | _ => NONE)
              | _ => NONE
          in go (body, []) end
      | _ => NONE
    end

  (* e's positions with a frame more, outermost -- the function e's code
     comes from, called from where the frames are -- in the code that runs
     in the activation e is put into, not in a function made there (as
     Simplify.inlinedFrom) *)
  fun inlinedFrom (frame : frame, outer : frame list) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, s, r, b) => Let (x, s, r, go b)
        | Fun (fs, b) => Fun (fs, go b)
        | Join (j, ps, body, sc) => Join (j, ps, go body, go sc)
        | If (c, t, f) => If (c, go t, go f)
        | Handle (a, x, h) => Handle (go a, x, go h)
        | Mark ((sp, frames), a) => Mark ((sp, frames @ frame :: outer), go a)
        | _ => e
    in go e end

  (* the marked functors' functions p defines, kept (a unit's, before its
     passes) *)
  fun keepMarked (p : program) : unit =
    List.app (fn Funs fs => List.app (fn (f : fundef) => if isSome (IntTable.find (!Elaborate.markedFunctions, #name f))
                                                         then IntTable.insert (!declaredBodies, #name f, f) else ()) fs
               | _ => ()) p

  (* a type name of its own for a datatype a copy declares: after the
     names MidCanon gave, in a whole program, else the elaborator's next *)
  fun freshTycon () : int =
    if !Pass.whole then let val s = !MidCanon.nextTycon in MidCanon.nextTycon := s + 1; s end
    else #stamp (Types.freshTycon ("", 0, false))

  (* a function's name is its first parameter's (Translate.funNames) *)
  fun isFunctor ({params, ...} : fundef) : bool =
    case params of
      (p, _) :: _ => (case IntMap.find (!Translate.funNames, p) of
                        SOME n => String.isPrefix "functor " n
                      | NONE => false)
    | [] => false

  (* ---- the types an application substitutes ---- *)

  (* What a type name becomes: a type of the variables (Ty.Var) that stand
     for its arguments, or another name *)
  datatype image = Body of int list * Ty.ty | Name of int

  (* the type t with each variable of m made what m says *)
  fun replaceVars (m : Ty.ty IntMap.map) (t : Ty.ty) : Ty.ty =
    if IntMap.isEmpty m then t
    else
      let
        fun go t =
          case Ty.view t of
            Ty.Var i => (case IntMap.find (m, i) of SOME u => u | NONE => t)
          | Ty.Con (s, n, args) => Ty.con (s, n, List.map go args)
          | Ty.Tuple ts => Ty.tuple (List.map go ts)
          | Ty.Arrow (a, b) => Ty.arrow (go a, go b)
          | _ => t
      in go t end

  (* The marker of an application (Translate.callExp): the pairs of its
     parameter's type names and its body's datatypes, each the name applied
     to variables and what it becomes *)
  fun markerType (r : rhs) : Ty.ty option =
    case r of
      Prim ("functor_marker", t, [Unit]) =>
        (case Ty.view t of
           Ty.Arrow (d, enc) =>
             if Ty.equal (d, Ty.unit) then
               (case Ty.view enc of
                  Ty.Tuple [bs, gs] =>
                    (case (Ty.view bs, Ty.view gs) of
                       (Ty.Tuple _, Ty.Tuple _) => SOME enc
                     | _ => NONE)
                | _ => NONE)
             else NONE
         | _ => NONE)
    | _ => NONE

  fun entries (enc : Ty.ty) : (int * image) list * (int * image) list =
    let
      fun entry t =
        case Ty.view t of
          Ty.Arrow (from, to) =>
            (case Ty.view from of
               Ty.Con (s, _, args) =>
                 (s, Body (List.map (fn a => case Ty.view a of Ty.Var i => i | _ => bug "a marker's argument") args, to))
             | _ => bug "a marker's name")
        | _ => bug "a marker's pair"
      fun list t = case Ty.view t of Ty.Tuple ts => List.map entry ts | _ => bug "a marker's pairs"
    in
      case Ty.view enc of
        Ty.Tuple [bs, gs] => (list bs, list gs)
      | _ => bug "a marker"
    end

  (* The datatypes a type names, after Ty.view: what a marker's images
     name *)
  fun namesIn (t : Ty.ty, acc : unit IntMap.map) : unit IntMap.map =
    case Ty.view t of
      Ty.Con (s, _, args) => List.foldl namesIn (IntMap.insert (acc, s, ())) args
    | Ty.Tuple ts => List.foldl namesIn acc ts
    | Ty.Arrow (a, b) => namesIn (b, namesIn (a, acc))
    | _ => acc

  (* ---- the program's state through the pass ---- *)

  type state =
    {(* the locals of copies made globals *)
     globalized : unit IntTable.table,
     (* what a variable dropped is, at the types it is used at *)
     alias : (Ty.ty list -> atom) IntTable.table,
     (* a global known to be a tuple of these, or a cast to unit of this
        atom of this type *)
     tuples : atom vector IntTable.table,
     casts : (atom * Ty.ty) IntTable.table,
     (* every global's scheme *)
     schemes : scheme IntTable.table,
     (* the datatypes the copies declared, each by the one it copies, and
        the instances of applications expanded *)
     copied : (int * int * {params : int list, cons : (int * string * Ty.ty option) list}) list ref,
     instances : int list ref,
     (* the instances' constructors, as the copies made them *)
     rebound : (int * {params : int list, cons : (int * string * Ty.ty option) list}) list ref,
     (* each copy of a body's datatype, by the datatype and what the names
        it reaches were made (copyKey) *)
     dcopies : int StringMap.map ref}

  fun newState () : state =
    {globalized = IntTable.table 1024, alias = IntTable.table 1024, tuples = IntTable.table 256,
     casts = IntTable.table 1024, schemes = IntTable.table 4096, copied = ref [], instances = ref [], rebound = ref [],
     dcopies = ref StringMap.empty}

  (* ---- copying a body ---- *)

  (* the type names a datatype's constructors name, by its stamp, for a
     program *)
  val datatypeNames : int list IntTable.table ref = ref (IntTable.table 256)
  val () = CompilerState.refRoot ("Expand.datatypeNames", datatypeNames, IntTable.copy)
  fun namesOfDatatype (s : int) : int list =
    case IntTable.find (!datatypeNames, s) of
      SOME l => l
    | NONE =>
        let
          val l = case Ty.datatypeOf s of
                    NONE => []
                  | SOME {cons, ...} =>
                      IntMap.listKeys (List.foldl (fn ((_, _, SOME a), acc) => namesIn (a, acc) | (_, acc) => acc) IntMap.empty cons)
        in IntTable.insert (!datatypeNames, s, l); l end

  (* e0 with fresh names for what it binds, the variables given (each
     monomorphic) the atoms given, the types substituted as sigma says,
     each datatype it declares over what sigma substitutes copied (into
     copied); a variable it does not bind kept, where free is true (a join
     point's body copied into the spine it is in, whose variables the
     spine rewrites after: the review of M6, finding 7), and otherwise a
     bug (a functor's body, closed but for its parameter) *)
  fun copyExp (st : state, sigma0 : image IntMap.map, given : (int * atom) list, e0 : exp) : exp =
    #1 (copyExpWith (st, sigma0, [], given, true, e0))

  (* the same, and the datatypes of made (each a body's datatype, by the
     name of its instance) entered again under their instances' names with
     their constructors as the copy has them: their types substituted, and
     the body's other datatypes they name the copy's *)
  and copyExpWith (st : state, sigma0 : image IntMap.map, made : (int * int) list, given : (int * atom) list, free : bool,
                   e0 : exp) : exp * unit =
    let
      val sigma = ref sigma0
      val memo : Ty.ty IntTable.table = IntTable.table 256
      (* the instances the applications in e0 make (their markers' body
         datatypes): each copy of a body has instances of its own, as each
         application of a functor makes new ones, whatever its argument
         -- one the outer result does not show would otherwise keep its name
         in every copy and be entered again by each, with the constructors
         of each copy's own copies of what it names (the review of M6,
         finding 3) *)
      val generated : unit IntTable.table = IntTable.table 16
      val () =
        let
          fun note r =
            case markerType r of
              SOME enc => List.app (fn (_, Body (_, to)) => (case Ty.view to of
                                                                 Ty.Con (c, _, _) => IntTable.insert (generated, c, ())
                                                               | _ => ())
                                     | _ => ()) (#2 (entries enc))
            | NONE => ()
          fun go e =
            case e of
              Let (_, _, r, b) => (note r; go b)
            | Fun (fs, b) => (List.app (fn (f : fundef) => go (#body f)) fs; go b)
            | Join (_, _, b, sc) => (go b; go sc)
            | If (_, t, f) => (go t; go f)
            | Handle (b, _, h) => (go b; go h)
            | Return r => note r
            | Mark (_, b) => go b
            | _ => ()
        in go e0 end
      fun isGenerated s = isSome (IntTable.find (generated, s)) andalso not (IntMap.member (sigma0, s))
      (* whether a datatype names what sigma substitutes, or an instance
         the copy makes its own, through those it names: worked out by a
         walk of all it reaches (a datatype of the body over an instance
         an application in it makes, of nothing the parameter gives, is
         the copy's too, as the instance is: MLton's whole compile) *)
      val dep : bool IntTable.table = IntTable.table 64
      (* NONE where its constructors name a substituted name; else the
         names they name *)
      fun direct (s : int) : int list option =
        let val names = namesOfDatatype s
        in if List.exists (fn n => IntMap.member (!sigma, n) orelse isGenerated n) names then NONE else SOME names end
      fun depends (s : int) : bool =
        case IntTable.find (dep, s) of
          SOME b => b
        | NONE =>
            let
              val seen : unit IntTable.table = IntTable.table 16
              fun reach [] = false
                | reach (n :: rest) =
                    if isSome (IntTable.find (seen, n)) then reach rest
                    else
                      (IntTable.insert (seen, n, ());
                       case direct n of
                         NONE => true
                       | SOME more => reach (more @ rest))
              val b = reach [s]
            in IntTable.insert (dep, s, b); b end
      fun ty (t : Ty.ty) : Ty.ty =
        case IntTable.find (memo, Ty.id t) of
          SOME u => u
        | NONE => let val u = ty' t in IntTable.insert (memo, Ty.id t, u); u end
      and ty' t =
        case Ty.view t of
          Ty.Con (s, n, args) =>
            let
              val args' = List.map ty args
              fun image (Body (vs, body)) =
                    replaceVars (ListPair.foldl (fn (v, a, m) => IntMap.insert (m, v, a)) IntMap.empty (vs, args')) body
                | image (Name s') = Ty.con (s', n, args')
            in
              case IntMap.find (!sigma, s) of
                SOME i => image i
              | NONE =>
                  if Ty.flatOf s = NONE andalso (isGenerated s orelse depends s) then image (instantiate s)
                  else Ty.con (s, n, args')
            end
        | Ty.Tuple ts => Ty.tuple (List.map ty ts)
        | Ty.Arrow (a, b) => Ty.arrow (ty a, ty b)
        | _ => t
      (* a datatype of the body's over what sigma substitutes, copied: once
         for what the names it reaches are made, which two copies share
         where both make them the same -- an instance two applications
         share (a nested application's that the outer result does not show,
         which keeps its name in every copy of the outer body) is entered
         again by each, and its constructors must name one copy of a
         datatype of the body they reach (fxp's ExtType and State) *)
      and instantiate (s : int) : image =
        let
          (* an instance an application in the body makes is this copy's
             own, and so is a datatype over one (copyKey) *)
          val key = if isGenerated s then NONE else copyKey s
        in
          case Option.mapPartial (fn k => StringMap.find (!(#dcopies st), k)) key of
            SOME s' => (sigma := IntMap.insert (!sigma, s, Name s'); Name s')
          | NONE =>
              let
                val s' = freshTycon ()
                val () = sigma := IntMap.insert (!sigma, s, Name s')
                val () = Option.app (fn k => #dcopies st := StringMap.insert (!(#dcopies st), k, s')) key
                val info = case Ty.datatypeOf s of
                             SOME {params, cons} => {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map ty a)) cons}
                           | NONE => bug "a datatype without constructors"
              in #copied st := (s, s', info) :: !(#copied st); Name s' end
        end
      (* the datatype s and what the application makes of each name it
         reaches (sigma0, not the copies this one has made so far, so that
         the order a copy meets the body's datatypes in changes nothing),
         through the body's datatypes it does not make anything: which
         determine its copy; NONE where it reaches an instance the copy
         makes its own, whose copy is the copy's own too *)
      and copyKey (s : int) : string option =
        let
          val seen : unit IntTable.table = IntTable.table 16
          val found : (int * string) list ref = ref []
          val own = ref false
          fun tyKey t =
            case Ty.view t of
              Ty.Con (c, _, args) => "c" ^ Int.toString c ^ "(" ^ String.concatWith "," (List.map tyKey args) ^ ")"
            | Ty.Tuple ts => "t(" ^ String.concatWith "," (List.map tyKey ts) ^ ")"
            | Ty.Arrow (a, b) => "a(" ^ tyKey a ^ "," ^ tyKey b ^ ")"
            | Ty.Gen i => "g" ^ Int.toString i
            | Ty.Var i => "v" ^ Int.toString i
            | Ty.ExnCon => "e"
          fun imageKey (Name c) = "n" ^ Int.toString c
            | imageKey (Body (vs, body)) = "b" ^ String.concatWith "," (List.map Int.toString vs) ^ ":" ^ tyKey body
          fun walk n =
            if isSome (IntTable.find (seen, n)) then ()
            else
              (IntTable.insert (seen, n, ());
               case IntMap.find (sigma0, n) of
                 SOME i => found := (n, imageKey i) :: !found
               | NONE => if isGenerated n then own := true else List.app walk (namesOfDatatype n))
          val () = IntTable.insert (seen, s, ())
          val () = List.app walk (namesOfDatatype s)
          val sorted = IntMap.listItemsi (List.foldl (fn ((n, k), m) => IntMap.insert (m, n, k)) IntMap.empty (!found))
        in
          if !own then NONE
          else SOME (Int.toString s ^ "|" ^ String.concatWith ";" (List.map (fn (n, k) => Int.toString n ^ "=" ^ k) sorted))
        end

      val vars : atom IntTable.table = IntTable.table 256
      val labels : int IntTable.table = IntTable.table 64
      fun rename x = let val x' = fresh () in IntTable.insert (vars, x, Var (x', [])); x' end
      fun label j = let val j' = fresh () in IntTable.insert (labels, j, j'); j' end
      fun named (x, x') = case IntMap.find (!Translate.funNames, x) of
                            SOME n => Translate.funNames := IntMap.insert (!Translate.funNames, x', n)
                          | NONE => ()
      (* a parameter, renamed, and the function's name with it *)
      fun param (x, t) = let val x' = rename x in named (x, x'); (x', ty t) end
      val () = List.app (fn (x, a) => IntTable.insert (vars, x, a)) given
      fun atom a =
        case a of
          Var (x, ts) =>
            (case IntTable.find (vars, x) of
               SOME (Var (x', _)) => Var (x', List.map ty ts)
             | SOME other => if null ts then other else bug ("v" ^ Int.toString x ^ ", given, used at types")
             | NONE => if free then Var (x, List.map ty ts) else bug ("v" ^ Int.toString x ^ " free in a functor's body"))
        | Global (g, ts) => Global (g, List.map ty ts)
        | Const (c, t) => Const (c, ty t)
        | Con0 (tag, t) => Con0 (tag, ty t)
        | Unit => Unit
      fun scheme ((vs, t) : scheme) : scheme = (vs, ty t)
      fun rhs r =
        case r of
          Atom a => Atom (atom a)
        | App (f, xs) => App (atom f, List.map atom xs)
        | Prim (p, t, xs) => Prim (p, ty t, List.map atom xs)
        | Tuple xs => Tuple (List.map atom xs)
        | Select (i, a) => Select (i, atom a)
        | Con (tag, t, a) => Con (tag, ty t, atom a)
        | Decon (tag, t, a) => Decon (tag, ty t, atom a)
        | ConTag a => ConTag (atom a)
        | NewExn s => NewExn s
        | BuiltinExn i => BuiltinExn i
        | MkExn (c, a) => MkExn (atom c, atom a)
        | ExnCon a => ExnCon (atom a)
        | ExnArg (t, a) => ExnArg (ty t, atom a)
        | SetGlobal (g, a) => SetGlobal (g, atom a)
      (* the test of an open constructor's descriptor (ToMid.opened), whose
         first branch makes or takes it apart as its datatype *)
      fun openTest (c, r, b) =
        case (r, b) of
          (Prim ("open_boxed", _, _), If (Var (c', []), fast, _)) => if c = c' then SOME fast else NONE
        | _ => NONE
      fun exp e =
        case e of
          Let (x, s, r, b) =>
            (case openTest (x, r, b) of
               SOME fast => exp fast
             | NONE => let val r' = rhs r val x' = rename x in Let (x', scheme s, r', exp b) end)
        | Fun (fs, b) =>
            let
              val names = List.map (fn (g : fundef) => rename (#name g)) fs
              val fs' = ListPair.map (fn (g, g') => fundef (g, g')) (fs, names)
            in Fun (fs', exp b) end
        | Join (j, ps, b, sc) =>
            let
              val ps' = List.map (fn (x, t) => (rename x, ty t)) ps
              val b' = exp b
              val j' = label j
            in Join (j', ps', b', exp sc) end
        | Jump (j, xs) =>
            (case IntTable.find (labels, j) of
               SOME j' => Jump (j', List.map atom xs)
             | NONE => bug ("j" ^ Int.toString j ^ " free in a functor's body"))
        | If (a, t, f) => If (atom a, exp t, exp f)
        | Handle (b, x, h) => let val b' = exp b val x' = rename x in Handle (b', x', exp h) end
        | Raise a => Raise (atom a)
        | Return r => Return (rhs r)
        | Mark (pos, b) => Mark (pos, exp b)
      and fundef ({tyvars, params, result, body, ...} : fundef, name') : fundef =
        let val ps = List.map param params
        in {name = name', tyvars = tyvars, params = ps, result = ty result, body = exp body} end
      val e = exp e0
      val () =
        List.app (fn (c, c') =>
                    case Ty.datatypeOf c of
                      SOME {params, cons} =>
                        #rebound st := (c', {params = params, cons = List.map (fn (t, n, a) => (t, n, Option.map ty a)) cons})
                                       :: !(#rebound st)
                    | NONE => ()) made
    in (e, ()) end

  (* The body of the functor's function f, its parameter the atom given *)
  fun copyBody (st : state, sigma : image IntMap.map, made : (int * int) list, f : fundef, arg : atom) : exp =
    case #params f of
      [(p, _)] => #1 (copyExpWith (st, sigma, made, [(p, arg)], false, #body f))
    | _ => bug "a functor's function of other than one parameter"

  (* ---- rewriting with what is known ---- *)

  fun substAtom (m : Ty.ty IntMap.map) (a : atom) : atom =
    if IntMap.isEmpty m then a
    else
      case a of
        Var (x, ts) => Var (x, List.map (Ty.subst m) ts)
      | Global (g, ts) => Global (g, List.map (Ty.subst m) ts)
      | Const (c, t) => Const (c, Ty.subst m t)
      | Con0 (tag, t) => Con0 (tag, Ty.subst m t)
      | Unit => Unit

  fun rwAtom (st : state) (a : atom) : atom =
    case a of
      Var (x, ts) =>
        (case IntTable.find (#alias st, x) of
           SOME f => f ts
         | NONE => if isSome (IntTable.find (#globalized st, x)) then Global (x, ts) else a)
    | Global (g, ts) =>
        (case IntTable.find (#alias st, g) of
           SOME f => f ts
         | NONE =>
             (* a unit's: a global of a unit before it that is another *)
             if !Pass.whole then a
             else case IntTable.find (!globalAliases, g) of SOME h => Global (h, ts) | NONE => a)
    | _ => a

  fun rwRhs (st : state) (r : rhs) : rhs =
    let val atom = rwAtom st
    in
      case r of
        Atom a => Atom (atom a)
      | App (f, xs) => App (atom f, List.map atom xs)
      | Prim (p, t, xs) => Prim (p, t, List.map atom xs)
      | Tuple xs => Tuple (List.map atom xs)
      | Select (i, a) => Select (i, atom a)
      | Con (tag, t, a) => Con (tag, t, atom a)
      | Decon (tag, t, a) => Decon (tag, t, atom a)
      | ConTag a => ConTag (atom a)
      | MkExn (c, a) => MkExn (atom c, atom a)
      | ExnCon a => ExnCon (atom a)
      | ExnArg (t, a) => ExnArg (t, atom a)
      | SetGlobal (g, a) => SetGlobal (g, atom a)
      | other => other
    end

  (* A step made simpler by what is known, and whether it was: a field of a
     known tuple; a cast to the same type; a cast back through unit of what
     was cast to unit from the type wanted, or from a polymorphic global's
     instance at it, or of a nullary constructor at another instance *)
  fun fold (st : state) (r : rhs) : rhs * bool =
    case r of
      Select (i, Global (g, [])) =>
        (case IntTable.find (#tuples st, g) of
           SOME v => if i < Vector.length v then (Atom (Vector.sub (v, i)), true) else (r, false)
         | NONE => (r, false))
    | Prim ("functor_cast", t, [a]) =>
        (case Ty.view t of
           Ty.Arrow (d, c) =>
             if Ty.equal (d, c) then (Atom a, true)
             else if not (Ty.equal (d, Ty.unit)) then (r, false)
             else
               (case a of
                  Global (g, _) =>
                    (case IntTable.find (#casts st, g) of
                       SOME (z, from) =>
                         if Ty.equal (from, c) then (Atom z, true)
                         else
                           (case z of
                              (* a nullary constructor, which a polymorphic
                                 value of the record is at unit for its type
                                 variables (`val index = NONE`): the same
                                 constructor at the instance wanted *)
                              Con0 (tag, _) =>
                                (case (Ty.view from, Ty.view c) of
                                   (Ty.Con (s1, _, _), Ty.Con (s2, _, _)) =>
                                     if s1 = s2 then (Atom (Con0 (tag, c)), true) else (r, false)
                                 | _ => (r, false))
                            | Global (f, _) =>
                                (* a global of a unit before this one, by
                                   the scheme its basis gives (the
                                   generator's earlier_unit_arg: an argument
                                   that names a polymorphic function of an
                                   earlier unit, at int -> int) *)
                                (case (case IntTable.find (#schemes st, f) of
                                         SOME s => SOME s
                                       | NONE => (SOME (ToMid.globalScheme f) handle Error.Bug _ => NONE)) of
                                   SOME (vs as _ :: _, tf) =>
                                     (case Ty.match (tf, c) of
                                        SOME m => (Atom (Global (f, List.map (fn v => case IntMap.find (m, v) of
                                                                                         SOME u => u
                                                                                       | NONE => Ty.unit) vs)), true)
                                      | NONE => (r, false))
                                 | _ => (r, false))
                            | _ => (r, false))
                     | NONE => (r, false))
                | _ => (r, false))
         | _ => (r, false))
    | _ => (r, false)

  (* The globals a function of the program sets (SetGlobal in a function's
     body: a dynamic module's slots, which RuneDynamic.load sets and
     Dynamic.reload sets again), whose value may change after it is read *)
  val changing : unit IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("Expand.changing", changing, IntTable.copy)
  fun noteChanging (p : program) : unit =
    let
      val t : unit IntTable.table = IntTable.table 16
      fun rhs (inFun, r) = case r of SetGlobal (g, _) => if inFun then IntTable.insert (t, g, ()) else () | _ => ()
      fun exp (inFun, e) =
        case e of
          Let (_, _, r, b) => (rhs (inFun, r); exp (inFun, b))
        | Fun (fs, b) => (List.app (fn (f : fundef) => exp (true, #body f)) fs; exp (inFun, b))
        | Join (_, _, b, sc) => (exp (inFun, b); exp (inFun, sc))
        | If (_, a, b) => (exp (inFun, a); exp (inFun, b))
        | Handle (a, _, h) => (exp (inFun, a); exp (inFun, h))
        | Mark (_, b) => exp (inFun, b)
        | Return r => rhs (inFun, r)
        | _ => ()
    in
      List.app (fn Val (_, _, e) => exp (false, e)
                 | Do (_, e) => exp (false, e)
                 | Funs fs => List.app (fn (f : fundef) => exp (true, #body f)) fs) p;
      changing := t
    end

  (* the functions of the units before this one known by name
     (Lower.knownBefore), which the driver says (Pipeline) *)
  val knownFunction : (int -> bool) ref = ref (fn _ => false)
  val () = CompilerState.cellRoot ("Expand.knownFunction", knownFunction)
  (* whether a global keeps the value it was first given: one the program
     defines and no function of it sets, or one of a unit before it whose
     basis says it is a function or another global (a value of another
     unit may be a dynamic module's slot) *)
  fun steady (st : state) (g : int) : bool =
    not (isSome (IntTable.find (!changing, g)))
    andalso (isSome (IntTable.find (#schemes st, g)) orelse !knownFunction g
             orelse isSome (IntTable.find (!globalAliases, g)))

  (* Whether x of scheme s may be dropped for the atom a: where s abstracts
     over variables, each use's types must reach all a names of them, as
     they do through the types a global of a closed scheme is given; not
     through a function whose own type names them free (ToMid lets one be,
     a type of its own, and a polymorphic alias abstract over it); and not
     for a global whose value may change (steady) *)
  fun aliasable (st : state) ((vs, _) : scheme, a : atom) : bool =
    case (vs, a) of
      (_, Global (g, _)) => steady st g andalso aliasable' st (vs, a)
    | _ => aliasable' st (vs, a)
  and aliasable' (st : state) (vs : int list, a : atom) : bool =
    case (vs, a) of
      ([], _) => true
    | (_, Global (g, ts)) =>
        (case IntTable.find (#schemes st, g) of
           SOME (gs, t) => List.length gs = List.length ts andalso List.all (fn v => List.exists (fn w => w = v) gs) (Ty.gens t)
         | NONE => false)
    | (_, Const _) => true
    | (_, Con0 _) => true
    | (_, Unit) => true
    | _ => false

  (* x of scheme s, which is the atom a, dropped *)
  fun setAlias (st : state) (x : int, (vs, _) : scheme, a : atom) : unit =
    IntTable.insert (#alias st, x,
                     case vs of
                       [] => (fn _ => a)
                     | _ => (fn ts => substAtom (ListPair.foldl (fn (v, t, m) => IntMap.insert (m, v, t)) IntMap.empty (vs, ts)) a))

  (* what a global whose value is r is known to be *)
  fun know (st : state) (g : int, s : scheme, r : rhs) : unit =
    (IntTable.insert (#schemes st, g, s);
     case r of
       Tuple xs => IntTable.insert (#tuples st, g, Vector.fromList xs)
     | Prim ("functor_cast", t, [a]) =>
         (case Ty.view t of
            Ty.Arrow (d, c) => if Ty.equal (c, Ty.unit) andalso not (Ty.equal (d, Ty.unit))
                               then IntTable.insert (#casts st, g, (a, d)) else ()
          | _ => ())
     | _ => ())

  (* A call of a global bound to a primitive (Translate.primAliases), which
     an alias made of a name of a copy's binding, the primitive's
     application, as Translate makes a call of the name: the steps that
     take its argument apart, each a variable's, and the primitive's step *)
  fun primCall (st : state) (r : rhs) : ((int * Ty.ty * rhs) list * rhs) option =
    case r of
      App (Global (h, ts), [a]) =>
        (* in a whole program MidCanon has renamed the globals, which
           Translate.primAliases and the bases name by the elaborator's
           stamps: none of them is there (the review of M6, finding 7), and
           Simplify inlines what an alias made of a binding to a primitive *)
        (case (if !Pass.whole then NONE
               else case IntMap.find (!Translate.primAliases, h) of
                      SOME p => SOME p
                    | NONE => IntTable.find (!primGlobals, h)) of
           NONE => NONE
         | SOME p =>
             let
               val sc = case IntTable.find (#schemes st, h) of
                          SOME s => SOME s
                        | NONE => (SOME (ToMid.globalScheme h) handle Error.Bug _ => NONE)
             in
               case sc of
                 SOME (vs, t) =>
                   if List.length vs <> List.length ts then NONE
                   else
                     let
                       val pty = if null vs then t
                                 else Ty.subst (ListPair.foldl (fn (v, u, m) => IntMap.insert (m, v, u)) IntMap.empty (vs, ts)) t
                       val n = Translate.primArity p
                     in
                       case Ty.view pty of
                         Ty.Arrow (d, _) =>
                           if n = 1 then SOME ([], Prim (p, pty, [a]))
                           else
                             (case Ty.view d of
                                Ty.Tuple ds =>
                                  if n > 1 andalso List.length ds = n then
                                    let val xs = List.map (fn d => (fresh (), d)) ds
                                    in SOME (ListPair.map (fn ((x, d), i) => (x, d, Select (i, a))) (xs, List.tabulate (n, fn i => i)),
                                             Prim (p, pty, List.map (fn (x, _) => Var (x, [])) xs))
                                    end
                                  else NONE
                              | _ => NONE)
                       | _ => NONE
                     end
               | NONE => NONE
             end)
    | _ => NONE

  fun withSteps (steps : (int * Ty.ty * rhs) list, e : exp) : exp =
    List.foldr (fn ((x, t, r), e) => Let (x, ([], t), r, e)) e steps

  (* An expression rewritten with what is known *)
  fun rewrite (st : state) (e : exp) : exp =
    let
      val atom = rwAtom st
      fun exp e =
        case e of
          Let (x, s, r, b) =>
            (case fold st (rwRhs st r) of
               (Atom a, true) => if aliasable st (s, a) then (setAlias st (x, s, a); exp b) else Let (x, s, Atom a, exp b)
             | (r', _) =>
                 case primCall st r' of
                   SOME (steps, r'') => withSteps (steps, Let (x, s, r'', exp b))
                 | NONE => Let (x, s, r', exp b))
        | Fun (fs, b) => Fun (List.map fundef fs, exp b)
        | Join (j, ps, b, sc) => Join (j, ps, exp b, exp sc)
        | Jump (j, xs) => Jump (j, List.map atom xs)
        | If (a, t, f) => If (atom a, exp t, exp f)
        | Handle (b, x, h) => Handle (exp b, x, exp h)
        | Raise a => Raise (atom a)
        | Return r =>
            let val r' = #1 (fold st (rwRhs st r))
            in case primCall st r' of SOME (steps, r'') => withSteps (steps, Return r'') | NONE => Return r' end
        | Mark (pos, b) => Mark (pos, exp b)
      and fundef ({name, tyvars, params, result, body} : fundef) : fundef =
        {name = name, tyvars = tyvars, params = params, result = result, body = exp body}
    in exp e end

  (* ---- the declarations of a copy as definitions ---- *)

  (* whether an expression gives its value (Return) in a tail position of
     its own, or only jumps and raises *)
  fun returns (e : exp) : bool =
    case e of
      Return _ => true
    | Let (_, _, _, b) => returns b
    | Fun (_, b) => returns b
    | Mark (_, b) => returns b
    | Join (_, _, b, sc) => returns b orelse returns sc
    | If (_, t, f) => returns t orelse returns f
    | Handle (a, _, h) => returns a orelse returns h
    | Jump _ => false
    | Raise _ => false

  (* e with each jump to j made what k makes of its arguments *)
  fun jumpsTo (j : int, k : atom list -> exp) (e : exp) : exp =
    let
      fun go e =
        case e of
          Let (x, s, r, b) => Let (x, s, r, go b)
        | Fun (fs, b) => Fun (fs, go b)
        | Join (j', ps, b, sc) => Join (j', ps, go b, go sc)
        | Jump (j', xs) => if j' = j then k xs else e
        | If (a, t, f) => If (a, go t, go f)
        | Handle (b, x, h) => Handle (go b, x, go h)
        | Mark (pos, b) => Mark (pos, go b)
        | _ => e
    in go e end

  (* The type variables a binder's type names and it does not abstract
     over: ToMid lets a local be of such a type, a type of its own (of a
     lambda a typed pattern binds, or a slot cast from unit), which a
     polymorphic variable is then bound to *)
  fun freeGens ((tvs, t) : scheme) : int list =
    List.filter (fn g => not (List.exists (fn v => v = g) tvs)) (Ty.gens t)

  fun small (e : exp) : bool =
    let
      fun go (e, n) =
        if n > 64 then n
        else
          case e of
            Let (_, _, _, b) => go (b, n + 1)
          | Mark (_, b) => go (b, n)
          | If (_, t, f) => go (f, go (t, n + 1))
          | Return _ => n + 1
          | Raise _ => n + 1
          | _ => 1000
    in go (e, 0) <= 64 end

  (* A local made a global of the scheme given: one that abstracts over
     the type variables its type names too, at those variables where it is
     used, so that a polymorphic alias of it is one (Shake) *)
  fun globalize (st : state) (x : int, sc as (tvs, t) : scheme) : scheme =
    let
      val () = IntTable.insert (#globalized st, x, ())
      val free = freeGens sc
      val sc' = (tvs @ free, t)
      val () = IntTable.insert (#schemes st, x, sc')
      val () = case free of
                 [] => ()
               | _ => IntTable.insert (#alias st, x, fn ts => Global (x, if List.length ts = List.length tvs
                                                                          then ts @ List.map Ty.gen free else ts))
    in sc' end

  (* The definitions of e, emitted by emit in order: the copy of a body,
     whose value is the record r of scheme s (final), or a definition of
     the top level in which an application is (Do, final NONE: sets are the
     globals it sets, each a definition of its own where it is set) *)
  fun spine (st : state, emit : def -> unit, final : (int * scheme) option, sets : (int * scheme) list ref) (e : exp) : unit =
    let
      fun place (mark, e) = case mark of SOME pos => Mark (pos, e) | NONE => e
      fun globalScheme (x, sc) = globalize st (x, sc)
      fun global x = ignore (globalScheme (x, ([], Ty.unit)))
      fun value (mark, x, sc, e) = emit (Val (x, sc, place (mark, e)))
      fun globalValue (mark, x, sc, e) = value (mark, x, globalScheme (x, sc), e)
      fun rest (mark, e) =
        (partial := !partial + 1;
         case final of
           SOME (r, s) => value (mark, r, s, rewrite st e)
         | NONE => (emit (Do (!sets, place (mark, rewrite st e))); sets := []))
      (* a global the Do sets, set: a definition of its own *)
      fun setsOne (mark, g, a) =
        case List.find (fn (h, _) => h = g) (!sets) of
          SOME (_, sg) =>
            (sets := List.filter (fn (h, _) => h <> g) (!sets);
             value (mark, g, sg, Return (Atom (rwAtom st a)));
             true)
        | NONE => false
      fun go (mark, e) =
        case e of
          Mark (pos, b) => go (SOME pos, b)
        | Let (x, sc, SetGlobal (g, a), b) =>
            if not (isSome final) andalso setsOne (mark, g, a) then (setAlias st (x, sc, Unit); go (mark, b))
            else rest (mark, e)
        | Let (x, sc, rh, b) =>
            (case fold st (rwRhs st rh) of
               (Atom a, _) =>
                 if aliasable st (sc, a) then (setAlias st (x, sc, a); go (mark, b))
                 else (globalValue (mark, x, sc, Return (Atom a)); go (mark, b))
             | (rh', _) =>
                 let val sc' = globalScheme (x, sc)
                 in know st (x, sc', rh'); value (mark, x, sc', Return rh'); go (mark, b) end)
        | Fun (fs, b) =>
            let
              val schemes = List.map (fn (f : fundef) => globalScheme (#name f, (#tyvars f, funTy f))) fs
            in
              emit (Funs (ListPair.map (fn (f : fundef, (tvs, _)) =>
                                          {name = #name f, tyvars = tvs, params = #params f,
                                           result = #result f, body = rewrite st (#body f)}) (fs, schemes)));
              go (mark, b)
            end
        | Return rh =>
            let val rh' = #1 (fold st (rwRhs st rh))
            in
              case final of
                SOME (r, s) =>
                  ((case rh' of Atom a => if aliasable st (s, a) then setAlias st (r, s, a) else () | _ => know st (r, s, rh'));
                   value (mark, r, s, Return rh'))
              | NONE =>
                  (case rh' of
                     Atom _ => ()
                   | SetGlobal (g, a) => if setsOne (mark, g, a) then () else emit (Do ([], place (mark, Return rh')))
                   | _ => emit (Do ([], place (mark, Return rh'))));
              if not (isSome final) andalso not (null (!sets)) then (emit (Do (!sets, Return (Atom Unit))); sets := []) else ()
            end
        | Join (j, ps, b, sc) =>
            if not (returns sc) andalso returns b then
              (case ps of
                 [(x, t)] =>
                   globalValue (mark, x, ([], t), rewrite st (jumpsTo (j, fn [a] => Return (Atom a)
                                                                            | _ => bug "a jump's arguments") sc))
               | [] => emit (Do ([], place (mark, rewrite st (jumpsTo (j, fn _ => Return (Atom Unit)) sc))))
               | _ =>
                   let
                     val tmp = fresh ()
                     val tt = Ty.tuple (List.map #2 ps)
                     val sct = globalScheme (tmp, ([], tt))
                   in
                     value (mark, tmp, sct, rewrite st (jumpsTo (j, fn xs => Return (Tuple xs)) sc));
                     List.foldl (fn ((x, t), i) =>
                                   (globalValue (mark, x, ([], t), Return (Select (i, rwAtom st (Var (tmp, []))))); i + 1))
                                0 ps;
                     ()
                   end;
               go (mark, b))
            else if returns sc andalso not (returns b) andalso small b then
              go (mark, jumpsTo (j, fn xs => copyExp (st, IntMap.empty, ListPair.zip (List.map #1 ps, xs), b)) sc)
            else rest (mark, e)
        | If (a, t, f) =>
            if returns t andalso not (returns f) then
              (emit (Do ([], place (mark, If (rwAtom st a, Return (Atom Unit), rewrite st f)))); go (mark, t))
            else if returns f andalso not (returns t) then
              (emit (Do ([], place (mark, If (rwAtom st a, rewrite st t, Return (Atom Unit))))); go (mark, f))
            else rest (mark, e)
        | _ => rest (mark, e)
    in go (NONE, e) end

  (* ---- the program ---- *)

  (* The application a definition is, where its value is a call of a
     functor's function defined in the program: its steps before the call
     (with the place of each), the function, the argument, and its marker
     if it is among the steps *)
  fun applicationOf (fns : fundef IntTable.table, e : exp) =
    let
      fun go (mark, steps, e) =
        case e of
          Mark (pos, b) => go (SOME pos, steps, b)
        | Let (x, s, r, b) => go (mark, (mark, x, s, r) :: steps, b)
        | Return (App (Global (g, _), [a])) =>
            (case IntTable.find (fns, g) of
               SOME f => SOME (List.rev steps, f, a, mark)
             | NONE =>
                 case IntTable.find (!imported, g) of
                   SOME f => SOME (List.rev steps, f, a, mark)
                 | NONE => NONE)
        | _ => NONE
    in go (NONE, [], e) end

  (* The program with each global a copy made that a value of the top level
     is under another name, at the same types -- an application's result,
     which a later unit may name -- given that name (the first such value's),
     and that value's definition gone: what a later unit calls is the copy's
     function, as static interpretation's copy is, not a closure in a global *)
  fun renameCopies (st : state, p : program) : program =
    let
      fun under (Mark (_, e)) = under e
        | under e = e
      fun candidate d =
        case d of
          Val (g, (gs, _), e) =>
            (case under e of
               Return (Atom (Global (h, ts))) =>
                 if isSome (IntTable.find (#globalized st, h))
                    andalso List.length ts = List.length gs
                    andalso ListPair.all (fn (t, v) => Ty.equal (t, Ty.gen v)) (ts, gs)
                    andalso (case IntTable.find (#schemes st, h) of
                               SOME (hs, _) => List.length hs = List.length gs
                             | NONE => false)
                 then SOME (g, h) else NONE
             | _ => NONE)
        | _ => NONE
      val found0 = List.mapPartial candidate p
      (* not a copy that is itself a value of another, nor a value that is
         itself such a copy: one step of renaming *)
      val aliasNames : unit IntTable.table = IntTable.table 64
      val targets : unit IntTable.table = IntTable.table 64
      val () = List.app (fn (g, h) => (IntTable.insert (aliasNames, g, ()); IntTable.insert (targets, h, ()))) found0
      val found = List.filter (fn (g, h) => not (isSome (IntTable.find (aliasNames, h))) andalso not (isSome (IntTable.find (targets, g))))
                              found0
      (* a copy several values are (`fun fromLarge ... val fromLargeWord =
         fromLarge`) takes the first one's name, and the others are that
         one, which a later unit then calls by name too (globalAliases) *)
      val names = List.foldl (fn ((g, h), m) => if IntMap.member (m, h) then m else IntMap.insert (m, h, g)) IntMap.empty found
      val gone = IntMap.foldl (fn (g, m) => IntMap.insert (m, g, ())) IntMap.empty names
    in
      if IntMap.isEmpty names then p
      else
        let
          fun name x = getOpt (IntMap.find (names, x), x)
          fun atom a = case a of Global (g, ts) => Global (name g, ts) | _ => a
          fun rhs r =
            case r of
              Atom a => Atom (atom a)
            | App (f, xs) => App (atom f, List.map atom xs)
            | Prim (p, t, xs) => Prim (p, t, List.map atom xs)
            | Tuple xs => Tuple (List.map atom xs)
            | Select (i, a) => Select (i, atom a)
            | Con (tag, t, a) => Con (tag, t, atom a)
            | Decon (tag, t, a) => Decon (tag, t, atom a)
            | ConTag a => ConTag (atom a)
            | MkExn (c, a) => MkExn (atom c, atom a)
            | ExnCon a => ExnCon (atom a)
            | ExnArg (t, a) => ExnArg (t, atom a)
            | SetGlobal (g, a) => SetGlobal (name g, atom a)
            | other => other
          fun exp e =
            case e of
              Let (x, s, r, b) => Let (x, s, rhs r, exp b)
            | Fun (fs, b) => Fun (List.map fundef fs, exp b)
            | Join (j, ps, b, sc) => Join (j, ps, exp b, exp sc)
            | Jump (j, xs) => Jump (j, List.map atom xs)
            | If (a, t, f) => If (atom a, exp t, exp f)
            | Handle (b, x, h) => Handle (exp b, x, exp h)
            | Raise a => Raise (atom a)
            | Return r => Return (rhs r)
            | Mark (pos, b) => Mark (pos, exp b)
          and fundef ({name = f, tyvars, params, result, body} : fundef) : fundef =
            {name = name f, tyvars = tyvars, params = params, result = result, body = exp body}
        in
          List.mapPartial (fn d =>
                             case d of
                               Val (g, s, e) => if IntMap.member (gone, g) andalso isSome (candidate d) then NONE
                                                else SOME (Val (name g, s, exp e))
                             | Funs fs => SOME (Funs (List.map fundef fs))
                             | Do (gs, e) => SOME (Do (gs, exp e))) p
        end
    end

  (* whether e calls one of the functors' functions fns *)
  fun calls (fns : fundef IntTable.table, e : exp) : bool =
    let
      fun app r = case r of
                    App (Global (g, _), _) => isSome (IntTable.find (fns, g)) orelse isSome (IntTable.find (!imported, g))
                  | _ => false
      fun exp e =
        case e of
          Let (_, _, r, b) => app r orelse exp b
        | Fun (fs, b) => List.exists (fn (f : fundef) => exp (#body f)) fs orelse exp b
        | Join (_, _, b, sc) => exp b orelse exp sc
        | If (_, t, f) => exp t orelse exp f
        | Handle (b, _, h) => exp b orelse exp h
        | Return r => app r
        | Mark (_, b) => exp b
        | _ => false
    in exp e end

  fun program (p : program) : program =
    let
      val () = (expanded := 0; kept := 0; partial := 0; overBudget := 0; most := 0; datatypeNames := IntTable.table 256)
      val st = newState ()
      val () = noteChanging p
      (* the functors' functions the program defines *)
      val fns : fundef IntTable.table = IntTable.table 64
      val () = List.app (fn Funs fs => List.app (fn (f : fundef) => if isFunctor f then IntTable.insert (fns, #name f, f) else ()) fs
                          | _ => ()) p
      val sizes : int IntTable.table = IntTable.table 64
      fun sizeOf (f : fundef) =
        case IntTable.find (sizes, #name f) of
          SOME n => n
        | NONE => let val n = Mid.size [Funs [f]] in IntTable.insert (sizes, #name f, n); n end
      (* each top-level application's budget left, by a number of its own *)
      val budgets : int IntTable.table = IntTable.table 64
      val nroots = ref 0
      val out : def list ref = ref []
      fun output d = out := d :: !out
      (* a marker defined by itself, waiting for its application *)
      val pending : (def * Ty.ty) option ref = ref NONE
      fun flush () = case !pending of SOME (d, _) => (output d; pending := NONE) | NONE => ()
      fun knowDef d =
        case d of
          Val (g, s, e) =>
            let
              fun under (Mark (_, e)) = under e
                | under e = e
            in
              case under e of
                Return (Atom a) => (IntTable.insert (#schemes st, g, s); if aliasable st (s, a) then setAlias st (g, s, a) else ())
              | Return r => know st (g, s, r)
              | _ => IntTable.insert (#schemes st, g, s)
            end
        | Funs fs => List.app (fn (f : fundef) => IntTable.insert (#schemes st, #name f, (#tyvars f, funTy f))) fs
        | Do (gs, _) => List.app (fn (g, s) => IntTable.insert (#schemes st, g, s)) gs
      fun rewriteDef d =
        case d of
          Val (g, s, e) => Val (g, s, rewrite st e)
        | Funs fs => Funs (List.map (fn (f : fundef) => {name = #name f, tyvars = #tyvars f, params = #params f,
                                                         result = #result f, body = rewrite st (#body f)}) fs)
        | Do (gs, e) => Do (gs, rewrite st e)
      (* the definitions left, each with its root, its depth and whether it
         is the program's (else a copy's, or a definition's flattened): each
         rewritten with what is known when it is reached, after the
         applications before it are expanded *)
      fun loop [] = ()
        | loop ((d, root, depth, original) :: rest) =
            let
              val d0 = d
              val d = rewriteDef d
              fun plain () = (knowDef d; output d; loop rest)
              fun markerOf (Val (_, _, e)) =
                    let fun under (Mark (_, e)) = under e | under (Return r) = markerType r | under _ = NONE
                    in under e end
                | markerOf _ = NONE
              (* a definition with an application of a functor's function
                 inside it, not as its value: its steps definitions of their
                 own, so that the application is one *)
              fun flatten () =
                let
                  val made : def list ref = ref []
                  fun emit d = made := d :: !made
                  val () =
                    case d0 of
                      Val (g, s, e) => spine (st, emit, SOME (g, s), ref []) e
                    | Do (gs, e) => spine (st, emit, NONE, ref gs) e
                    | Funs _ => ()
                in loop (List.map (fn d => (d, root, depth, false)) (List.rev (!made)) @ rest) end
            in
              case markerOf d of
                SOME enc => (flush (); pending := SOME (d, enc); loop rest)
              | NONE =>
                  case d of
                    Val (r, s, e) =>
                      (case applicationOf (fns, e) of
                         NONE => if original andalso calls (fns, e) andalso Pass.spend () then flatten () else plain ()
                       | SOME (steps, f, a, mark) =>
                           let
                             val inSteps = List.find (fn (_, _, _, rh) => isSome (markerType rh)) steps
                             (* a marker among its steps is its own; else the one
                                waiting is *)
                             val () = if isSome inSteps then flush () else ()
                             val enc = case inSteps of
                                         SOME (_, _, _, rh) => markerType rh
                                       | NONE => Option.map #2 (!pending)
                             val (root', left) =
                               case root of
                                 SOME k => (k, getOpt (IntTable.find (budgets, k), 0))
                               | NONE => let val k = !nroots in nroots := k + 1; IntTable.insert (budgets, k, !budget); (k, !budget) end
                             val n = sizeOf f
                           in
                             if not (isSome enc) orelse n > left orelse depth >= maxDepth orelse not (Pass.spend ()) then
                               (kept := !kept + 1;
                                if n > left then overBudget := !overBudget + 1 else ();
                                flush (); plain ())
                             else
                               let
                                 val () = IntTable.insert (budgets, root', left - n)
                                 val () = most := Int.max (!most, !budget - (left - n))
                                 val () = expanded := !expanded + 1
                                 val () = pending := NONE
                                 val enc = valOf enc
                                 val (bs, gs) = entries enc
                                 val () = List.app (fn (_, Body (_, to)) =>
                                                         (case Ty.view to of
                                                            Ty.Con (c', _, _) => #instances st := c' :: !(#instances st)
                                                          | _ => ())
                                                     | _ => ()) gs
                                 val sigma = List.foldl (fn ((s, i), m) => IntMap.insert (m, s, i)) IntMap.empty (bs @ gs)
                                 val made : def list ref = ref []
                                 fun emit d = made := d :: !made
                                 (* the steps before the call: definitions of their own *)
                                 val () =
                                   List.app (fn (mk, x, sc, rh) =>
                                               if isSome (markerType rh) then ()
                                               else
                                                 case fold st (rwRhs st rh) of
                                                   (Atom a, true) =>
                                                     if aliasable st (sc, a) then setAlias st (x, sc, a)
                                                     else emit (Val (x, globalize st (x, sc), Return (Atom a)))
                                                 | (rh', _) =>
                                                     let val sc' = globalize st (x, sc)
                                                     in know st (x, sc', rh');
                                                        emit (Val (x, sc', case mk of SOME pos => Mark (pos, Return rh') | NONE => Return rh'))
                                                     end)
                                            steps
                                 val a' = rwAtom st a
                                 val named = List.mapPartial (fn (c, Body (_, to)) =>
                                                                  (case Ty.view to of
                                                                     Ty.Con (c', _, _) => SOME (c, c')
                                                                   | _ => NONE)
                                                              | _ => NONE) gs
                                 val () = case IntTable.find (!importedNames, #name f) of
                                            SOME l => List.app (fn (x, n) => Translate.funNames := IntMap.insert (!Translate.funNames, x, n)) l
                                          | NONE => ()
                                 val body = copyBody (st, sigma, named, f, a')
                                 val body = case mark of SOME pos => Mark (pos, body) | NONE => body
                                 val nMade = List.length (!made)
                                 val () = spine (st, emit, SOME (r, s), ref []) body
                                 (* what the copy's declarations run, in a frame of the
                                    functor's function called where the application is,
                                    as at -O0 (the review of M6, finding 4): not the
                                    steps before the call, nor its functions, which run
                                    in activations of their own *)
                                 val name = case #params f of
                                              (p, _) :: _ => getOpt (IntMap.find (!Translate.funNames, p), "functor")
                                            | [] => "functor"
                                 fun frame d =
                                   case mark of
                                     SOME (sp, outer) =>
                                       (case d of
                                          Val (x, sc, e) => Val (x, sc, inlinedFrom ({name = name, site = SOME sp}, outer) e)
                                        | Do (gs, e) => Do (gs, inlinedFrom ({name = name, site = SOME sp}, outer) e)
                                        | _ => d)
                                   | NONE => d
                                 val all = List.rev (!made)
                                 val made = List.take (all, nMade) @ List.map frame (List.drop (all, nMade))
                                 val made = List.map (fn d => (d, SOME root', depth + 1, false)) made
                               in loop (made @ rest) end
                           end)
                  | Do (_, e) => if original andalso calls (fns, e) andalso Pass.spend () then flatten () else plain ()
                  | _ => plain ()
            end
      val () = loop (List.map (fn d => (d, NONE, 0, true)) p)
      val () = flush ()
      val p' = renameCopies (st, List.rev (!out))
      (* a unit's globals that are others, at the types they abstract over
         (and as their types say: as a later unit names them) *)
      val () =
        if !Pass.whole then ()
        else
          let
            fun under (Mark (_, e)) = under e
              | under e = e
            fun schemeOf g = SOME (ToMid.globalScheme g) handle Error.Bug _ => NONE
          in
            List.app (fn Val (g, (gs, _), e) =>
                           (case under e of
                              Return (Atom (Global (h, ts))) =>
                                if steady st h andalso List.length ts = List.length gs
                                   andalso ListPair.all (fn (t, v) => Ty.equal (t, Ty.gen v)) (ts, gs)
                                   andalso (case (schemeOf g, schemeOf h) of
                                              (SOME (gv, _), SOME (hv, _)) => gv = gs andalso List.length hv = List.length gs
                                            | _ => false)
                                then IntTable.insert (!globalAliases, g, h) else ()
                            | _ => ())
                       | Funs fs =>
                           List.app (fn (f : fundef) =>
                                       case primOfFunction f of
                                         SOME p => IntTable.insert (!primGlobals, #name f, p)
                                       | NONE => ()) fs
                       | _ => ()) p'
          end
      (* the datatypes the copies declared, entered *)
      val copied = List.rev (!(#copied st))
      val () = List.app (fn (_, s', info) => Ty.bindDatatypeDirect (s', info)) copied
      val () = List.app Ty.bindDatatypeDirect (List.rev (!(#rebound st)))
      (* the layouts: the datatypes an application left a call takes keep
         the body's layout, whose descriptors were worked out from it *)
      val taken : unit IntMap.map ref = ref IntMap.empty
      fun scanExp e =
        case e of
          Let (_, _, r, b) => (scanRhs r; scanExp b)
        | Fun (fs, b) => (List.app (fn (f : fundef) => scanExp (#body f)) fs; scanExp b)
        | Join (_, _, b, sc) => (scanExp b; scanExp sc)
        | If (_, t, f) => (scanExp t; scanExp f)
        | Handle (b, _, h) => (scanExp b; scanExp h)
        | Return r => scanRhs r
        | Mark (_, b) => scanExp b
        | _ => ()
      and scanRhs r =
        case markerType r of
          SOME enc =>
            let val (bs, gs) = entries enc
            in List.app (fn (_, Body (_, to)) => taken := namesIn (to, !taken) | _ => ()) (bs @ gs) end
        | NONE => ()
      val () = if null copied andalso null (!(#instances st)) then ()
               else List.app (fn Val (_, _, e) => scanExp e
                               | Funs fs => List.app (fn (f : fundef) => scanExp (#body f)) fs
                               | Do (_, e) => scanExp e) p'
      fun isTaken s = IntMap.member (!taken, s)
      val () = List.app (fn c' => if isTaken c' orelse not (IntMap.member (!Ty.pinned, c')) then ()
                                  else Ty.pinned := IntMap.remove (!Ty.pinned, c')) (!(#instances st))
      val () = List.app (fn (s, s', _) => if isTaken s' then Ty.pinLayout (s', Ty.elabLayout s) else ()) copied
      val () =
        if !stats then
          Pass.eprint ("expand: " ^ Int.toString (!expanded) ^ " applications expanded, " ^ Int.toString (!kept)
                       ^ " left calls (" ^ Int.toString (!overBudget) ^ " past the budget), " ^ Int.toString (!partial)
                       ^ " copies not all definitions; at most " ^ Int.toString (!most)
                       ^ " nodes copied for a top-level application\n")
        else ()
    in p' end
end
