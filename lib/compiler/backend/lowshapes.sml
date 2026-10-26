(* The shapes of Low's values, and the layouts of constructors across the
   functions of a program (the linting roadmap's D8, D14 and M6): checked
   after the pass lower, from level 1 of the lint, beside LowLint, which
   holds each value to a representation and each layout to what made it in
   the same function.

   A shape is what a value is in the heap or out of it: a tuple of n
   fields, a value of a datatype (by its stamp), a closure, an object of
   another kind (a string, an array, a ref, an exception...), or a value no
   object (an int, a word, a char, a real, unit); or unknown -- a type
   variable, an abstract type, nothing said. Each Low variable has the one
   its Mid type says, which Lower keeps (Lower.lastTys) but for a variable
   it shares between types on purpose (defAny), or else the one the
   operation that makes it says. Two agree where they are the same or one is
   unknown. The rules:
   * what makes a variable agrees with its type; a jump's arguments with the
     block's parameters, a known call's with the function's, the values a
     closure captures with what its function reads of them (Env), and a
     field read of a tuple or a constructor made in the function with what
     it was made of;
   * a Select is of a tuple of more fields than its index; a Call and a
     TailCall of a closure; ConTag, IfTag and Switch of a datatype's value;
   * a Field and a Decon are of a datatype's value; every Con of a (stamp,
     tag) in the program is of one number of fields, which every Field of
     it is below, two or more, and every Decon is 1 of: the producers of a
     layout held to its consumers, wherever they are, which is what a
     constructor built boxed in one function and taken apart flat in another
     breaks (Rep says the layout, and both are made from it: not compared);
     and each field a Con makes, a Field reads or a Decon takes agrees with
     what the datatype declares of it, where the layout is the declaration's
     (Ty.layoutOf): a field of a type variable's is unknown;
   * a Field and a Decon of a datatype of more than one constructor are of
     a value whose tag is known to be theirs, where they are: a test of its
     tag comes first on every way there (IfTag, Switch, or ConTag compared
     with a constant by imm_eq, poly_eq or int_eq, then If), or it was made
     by that constructor, or it is a block's parameter every jump to which
     passes such a value. A datatype open to a functor's argument, whose
     layout a descriptor says (Ty.isOpen, Ty.flatOf), is left out.
   --pass-stats counts what was checked against a known shape and what was
   not ("shaped", "unshaped" on the line of `shapes`). RUNE_SHAPES=1 runs it
   at every level, 0 at none. A breach is a bug of the compiler, raised as
   Error.Bug. *)
structure LowShapes =
struct
  open Low

  datatype shape = Unknown | Imm | Tup of int | Data of int | Clo | Opaque of string
  (* what a test of tags says on its way where it holds *)
  datatype test = OfTag of var * int | Same of var * var

  fun show s =
    case s of
      Unknown => "unknown" | Imm => "no object" | Tup n => "a tuple of " ^ Int.toString n
    | Data st => "a value of datatype " ^ Int.toString st | Clo => "a closure" | Opaque k => "an object (" ^ k ^ ")"

  val immediates = List.map (fn (c : Types.tycon) => #stamp c)
                            [Types.intTycon, Types.wordTycon, Types.int64Tycon, Types.word64Tycon, Types.realTycon, Types.charTycon]
  (* a type's shape, given each datatype's tags by its stamp (NONE: no
     datatype) *)
  fun ofTy (consOf : int -> int list option) (t : Ty.ty) : shape =
    case Ty.view t of
      Ty.Tuple [] => Imm
    | Ty.Tuple ts => Tup (List.length ts)
    | Ty.Arrow _ => Clo
    | Ty.ExnCon => Opaque "exception constructor"
    | Ty.Gen _ => Unknown
    | Ty.Var _ => Unknown
    | Ty.Con (stamp, _, _) =>
        if List.exists (fn s => s = stamp) immediates then Imm
        else if stamp = #stamp Types.stringTycon orelse stamp = #stamp Types.bytearrayTycon then Opaque "bytes"
        else if stamp = #stamp Types.realarrayTycon then Opaque "reals"
        else if stamp = #stamp Types.exnTycon then Opaque "exception"
        else
          case consOf stamp of
            SOME _ => Data stamp
          | NONE =>
              if stamp = #stamp Types.arrayTycon then Opaque "array"
              else if stamp = #stamp Types.vectorTycon then Opaque "vector"
              else if stamp = #stamp Types.refTycon then Opaque "ref"
              else Unknown

  fun agree (a, b) = a = Unknown orelse b = Unknown orelse a = b

  (* what an operation makes, where it alone says *)
  fun made (oper : operation) : shape =
    case oper of
      Const (Lambda.CString _) => Opaque "bytes"
    | Const _ => Imm
    | Unit => Imm
    | Tuple [] => Imm
    | Tuple vs => Tup (List.length vs)
    | Self => Clo
    | Closure _ => Clo
    | NewExn _ => Opaque "exception constructor"
    | BuiltinExn _ => Opaque "exception constructor"
    | ExnCon _ => Opaque "exception constructor"
    | MkExn _ => Opaque "exception"
    | ConTag _ => Imm
    | SetGlobal _ => Imm
    | SetEnv _ => Imm
    | _ => Unknown


  (* the tags a value may have, as a sorted list; a variable not in a map
     of them may have any *)
  fun union (a : int list, b : int list) : int list =
    case (a, b) of
      ([], _) => b
    | (_, []) => a
    | (x :: xs, y :: ys) => if x = y then x :: union (xs, ys) else if x < y then x :: union (xs, b) else y :: union (a, ys)
  fun without (a : int list, ts : int list) = List.filter (fn x => not (List.exists (fn t => t = x) ts)) a
  fun sort (ts : int list) = List.foldl (fn (t, acc) => union ([t], acc)) [] ts
  (* What is known of tags where a block begins: the tags each variable may
     have, and the variables whose tags are each one's, as a test of the
     two said (imm_eq of their ConTags) *)
  type facts = {tags : int list IntMap.map, eqs : int list IntMap.map}
  val nothing : facts = {tags = IntMap.empty, eqs = IntMap.empty}
  (* what holds on every way of two: what each knows, the tags of either *)
  fun meet ({tags = a, eqs = ea} : facts, {tags = b, eqs = eb} : facts) : facts =
    {tags = IntMap.foldli (fn (x, ts, m) => case IntMap.find (b, x) of SOME us => IntMap.insert (m, x, union (ts, us)) | NONE => m)
                          IntMap.empty a,
     eqs = IntMap.foldli (fn (x, ys, m) =>
                            case IntMap.find (eb, x) of
                              SOME zs => (case List.filter (fn y => List.exists (fn z => z = y) zs) ys of
                                            [] => m
                                          | both => IntMap.insert (m, x, both))
                            | NONE => m)
                         IntMap.empty ea}

  fun setting () = case OS.Process.getEnv "RUNE_SHAPES" of SOME s => s | NONE => ""
  (* the level of lint it runs from: LowLint's, 1, unless RUNE_SHAPES says
     always (any level, off too) or never *)
  fun level () = case setting () of "" => SOME 1 | "0" => NONE | _ => SOME Pass.off
  val () = Lower.shapesChecked := (fn () => case level () of SOME l => Pass.linting' l | NONE => false)

  (* The check, given each function's types by variable (tysOf, by its
     id): Lower's (check), or a test's. *)
  fun checkWith (tysOf : int -> var -> Ty.ty option) (p : program) : unit =
    let
      fun bug msg = Error.bug msg
      (* each datatype's tags, by its stamp, once *)
      val consMemo : int list option IntTable.table = IntTable.table 64
      fun consOf (stamp : int) : int list option =
        case IntTable.find (consMemo, stamp) of
          SOME c => c
        | NONE =>
            let val c = Option.map (fn {cons, ...} => List.map #1 cons) (Ty.datatypeOf stamp)
            in IntTable.insert (consMemo, stamp, c); c end
      (* the tags of a datatype's constructors, where it has more than one
         and its layout is its own *)
      fun tagsOf (stamp : int) : int list option =
        case Ty.flatOf stamp of
          SOME _ => NONE
        | NONE =>
            if Ty.isOpen stamp then NONE
            else case consOf stamp of SOME (ts as _ :: _ :: _) => SOME ts | _ => NONE
      val ofTy = ofTy consOf
      (* the shapes of a constructor's fields as its datatype declares them,
         where its layout is the declaration's: n of them, for one laid out
         flat; one, its argument, for one boxed *)
      (* by stamp, then tag: no int need hold the two together *)
      val declMemo : shape list option IntMap.map IntTable.table = IntTable.table 64
      fun declared (stamp : int, tag : int) : shape list option =
        case Option.mapPartial (fn m => IntMap.find (m, tag)) (IntTable.find (declMemo, stamp)) of
          SOME d => d
        | NONE =>
            let
              val d =
                case (Ty.datatypeOf stamp, List.find (fn (t, _) => t = tag) (Ty.layoutOf stamp)) of
                  (SOME {cons, ...}, SOME (_, lay)) =>
                    (case (List.find (fn (t, _, _) => t = tag) cons, lay) of
                       (SOME (_, _, SOME arg), SOME n) =>
                         (case Ty.view arg of
                            Ty.Tuple ts => if List.length ts = n then SOME (List.map ofTy ts) else NONE
                          | _ => NONE)
                     | (SOME (_, _, SOME arg), NONE) => SOME [ofTy arg]
                     | _ => NONE)
                | _ => NONE
            in
              IntTable.insert (declMemo, stamp, IntMap.insert (case IntTable.find (declMemo, stamp) of SOME m => m | NONE => IntMap.empty,
                                                               tag, d));
              d
            end
      val shaped = ref 0
      val unshaped = ref 0
      val byId : func IntTable.table = IntTable.table 256
      val () = List.app (fn (f : func) => IntTable.insert (byId, #id f, f)) p
      fun named (f : func) = "function f" ^ Int.toString (#id f) ^ " (" ^ #name f ^ ")"
      fun v x = "v" ^ Int.toString x

      (* each function's shapes, by variable: its type's, else what makes it,
         which agrees with its type *)
      (* and what made each of its variables *)
      val shapesOf : (shape vector * operation option array) IntTable.table = IntTable.table 256
      fun info (f : func) : shape vector * operation option array =
        case IntTable.find (shapesOf, #id f) of
          SOME s => s
        | NONE =>
            let
              val tyOf = tysOf (#id f)
              val n = Int.max (#nvars f, 1)
              val a = Array.tabulate (n, fn x => case tyOf x of SOME t => ofTy t | NONE => Unknown)
              val makes = Array.array (n, NONE)
              val () =
                List.app (fn ({label, instrs, ...} : block) =>
                            List.app (fn Def (x, oper) =>
                                           if x < 0 orelse x >= n then ()
                                           else
                                             let val m = made oper
                                             in
                                               Array.update (makes, x, SOME oper);
                                               if agree (m, Array.sub (a, x)) then
                                                 (if Array.sub (a, x) = Unknown then Array.update (a, x, m) else ())
                                               else bug (named f ^ ", b" ^ Int.toString label ^ ": " ^ v x ^ " is made " ^ show m
                                                         ^ " where its type says " ^ show (Array.sub (a, x)))
                                             end
                                       | _ => ()) instrs)
                         (#blocks f)
              val s = (Array.vector a, makes)
            in IntTable.insert (shapesOf, #id f, s); s end
      fun shapes f = #1 (info f)
      fun shapeIn (s : shape vector, x : var) = if x >= 0 andalso x < Vector.length s then Vector.sub (s, x) else Unknown

      (* the number of fields each (stamp, tag) is made of, by the program's
         Cons, and where first *)
      val fieldsMade : (int * func * int) IntMap.map IntTable.table = IntTable.table 64
      fun madeOf (stamp, tag) = Option.mapPartial (fn m => IntMap.find (m, tag)) (IntTable.find (fieldsMade, stamp))
      val () =
        List.app (fn (f : func) =>
                    let val s = shapes f
                    in
                      List.app (fn ({label, instrs, ...} : block) =>
                                  List.app (fn Def (x, Con (tag, vs)) =>
                                                 (case shapeIn (s, x) of
                                                    Data st =>
                                                      let val n = List.length vs
                                                      in
                                                        case madeOf (st, tag) of
                                                          NONE => IntTable.insert (fieldsMade, st,
                                                                                   IntMap.insert (case IntTable.find (fieldsMade, st) of
                                                                                                    SOME m => m | NONE => IntMap.empty,
                                                                                                  tag, (n, f, label)))
                                                        | SOME (m, g, l) =>
                                                            if m = n then ()
                                                            else bug (named f ^ ", b" ^ Int.toString label ^ ": constructor " ^ Int.toString tag
                                                                      ^ " of datatype " ^ Int.toString st ^ " made of " ^ Int.toString n
                                                                      ^ " fields, where " ^ named g ^ ", b" ^ Int.toString l ^ " makes it of "
                                                                      ^ Int.toString m)
                                                      end
                                                  | _ => unshaped := !unshaped + 1)
                                             | _ => ()) instrs)
                               (#blocks f)
                    end)
                 p
      fun fieldsOf (st, tag) = Option.map #1 (madeOf (st, tag))

      (* what each function reads of each value it captures, where its
         shape is known *)
      val envShapes : (int * shape) list IntTable.table = IntTable.table 256
      fun envOf g =
        case IntTable.find (envShapes, g) of
          SOME l => l
        | NONE =>
            (case IntTable.find (byId, g) of
               NONE => []
             | SOME gf =>
                 let
                   val s = shapes gf
                   val l = List.concat (List.map (fn ({instrs, ...} : block) =>
                                                    List.mapPartial (fn Def (x, Env i) => (case shapeIn (s, x) of Unknown => NONE | sh => SOME (i, sh))
                                                                      | _ => NONE) instrs)
                                                 (#blocks gf))
                 in IntTable.insert (envShapes, g, l); l end)

      fun func (f : func) =
        let
          val s = shapes f
          fun sh x = shapeIn (s, x)
          val bv = Vector.fromList (#blocks f)
          val nb = Vector.length bv
          val index : int IntMap.map = #1 (Vector.foldl (fn ({label, ...} : block, (m, i)) => (IntMap.insert (m, label, i), i + 1))
                                                       (IntMap.empty, 0) bv)
          fun blockOf l = IntMap.find (index, l)
          (* what made each variable defined in the function *)
          val makesA = #2 (info f)
          fun makesOf x = if x >= 0 andalso x < Array.length makesA then Array.sub (makesA, x) else NONE
          (* here and what are made where a breach is said, as are all the
             words of where it is and of what *)
          fun agreeing (here, x, wanted, what) =
            if agree (sh x, wanted) then ()
            else bug (here () ^ ": " ^ v x ^ " is " ^ show (sh x) ^ " where " ^ what () ^ " is " ^ show wanted)
          fun args (here, xs, ps, pshape, what) =
            let
              fun go (k, x :: xs, p :: ps) = (agreeing (here, x, pshape p, fn () => what k); go (k + 1, xs, ps))
                | go _ = ()
            in go (0, xs, ps) end
          fun callee (here, g, xs) =
            case IntTable.find (byId, g) of
              SOME gf => let val gs = shapes gf
                         in args (here, xs, #params gf, fn p => shapeIn (gs, p), fn k => "parameter " ^ Int.toString k ^ " of f" ^ Int.toString g) end
            | NONE => ()
          fun captured (here, g, k, y) =
            List.app (fn (j, wanted) => if j = k then agreeing (here, y, wanted, fn () => "env " ^ Int.toString k ^ " of f" ^ Int.toString g) else ())
                     (envOf g)
          (* a subject of what wants a shape: ok says of a known one *)
          fun subject (here, what, x, ok) =
            case sh x of
              Unknown => unshaped := !unshaped + 1
            | s' => if ok s' then shaped := !shaped + 1 else bug (here () ^ ": " ^ what () ^ " of " ^ v x ^ ", which is " ^ show s')
          fun isData (Data _) = true
            | isData _ = false

          (* what tags each variable may have where each block begins, from
             the ways into it, in their order (every way goes forward but a
             jump back to a loop's head, where what holds was known before
             it: a variable's tag never changes) *)
          val entries : facts option array = Array.array (Int.max (nb, 1), NONE)
          (* a loop's head, which a jump back goes to, and a handler's block,
             entered where its region raises: what holds there is not
             worked out *)
          val backInto = Array.array (Int.max (nb, 1), false)
          (* reached on a way from the entry: a block that is not is dead,
             and nothing is known of its tags *)
          val reached = Array.array (Int.max (nb, 1), false)
          val () = if nb > 0 then Array.update (reached, 0, true) else ()
          (* the jumps into each block's parameters so far: the tags of each
             argument, or NONE where one may have any *)
          val paramTags : int list option list option array = Array.array (Int.max (nb, 1), NONE)
          fun tagsOfShape x = case sh x of Data st => tagsOf st | _ => NONE
          fun arrive (from, j, facts, argTags) =
            if j <= from then ()
            else if not (Array.sub (reached, from)) then ()
            else
              (Array.update (reached, j, true);
               Array.update (entries, j, SOME (case Array.sub (entries, j) of NONE => facts | SOME m => meet (m, facts)));
               case argTags of
                 NONE => ()
               | SOME ts =>
                   Array.update (paramTags, j,
                                 SOME (case Array.sub (paramTags, j) of
                                         NONE => ts
                                       | SOME us => ListPair.map (fn (SOME a, SOME b) => SOME (union (a, b)) | _ => NONE) (us, ts))))
          (* the tags of x that facts know, or what made it *)
          fun known ({tags, ...} : facts, x) =
            case IntMap.find (tags, x) of
              SOME ts => SOME ts
            | NONE =>
                case makesOf (x) of
                  SOME (Con (tag, _)) => SOME [tag]
                | SOME (Con0 tag) => SOME [tag]
                | _ => NONE
          fun possible (facts, x) = case known (facts, x) of SOME ts => SOME ts | NONE => tagsOfShape x
          fun equals ({eqs, ...} : facts, x) = case IntMap.find (eqs, x) of SOME ys => ys | NONE => []
          (* x's tags, and those of the variables whose tags are its, as f
             says of each *)
          fun narrow (facts as {tags, eqs} : facts, x, f : int list -> int list) : facts =
            {tags = List.foldl (fn (z, m) => case possible (facts, z) of SOME ts => IntMap.insert (m, z, f ts) | NONE => m)
                               tags (x :: equals (facts, x)),
             eqs = eqs}
          (* a and b have one tag: each knows what the other does *)
          fun equate (facts as {tags, eqs} : facts, a, b) : facts =
            let
              val both =
                case (possible (facts, a), possible (facts, b)) of
                  (SOME ta, SOME tb) => SOME (List.filter (fn t => List.exists (fn u => u = t) tb) ta)
                | (SOME ta, NONE) => SOME ta
                | (NONE, SOME tb) => SOME tb
                | (NONE, NONE) => NONE
              val group = a :: b :: equals (facts, a) @ equals (facts, b)
              fun others x = List.filter (fn y => y <> x) group
            in
              {tags = case both of SOME ts => List.foldl (fn (z, m) => IntMap.insert (m, z, ts)) tags group | NONE => tags,
               eqs = List.foldl (fn (z, m) => IntMap.insert (m, z, others z)) eqs group}
            end
          (* where a Field's or a Decon's tag is known to be the one *)
          fun tagged (here, live, what, x, tag, facts) =
            case (live, sh x) of
              (true, Data st) =>
                (case tagsOf st of
                   NONE => ()
                 | SOME _ =>
                     case known (facts, x) of
                       SOME [] => ()          (* no value has a tag here: a way no value takes *)
                     | SOME [t] => if t = tag then ()
                                   else bug (here () ^ ": " ^ what () ^ " of " ^ v x ^ ", whose tag is " ^ Int.toString t)
                     | SOME ts => bug (here () ^ ": " ^ what () ^ " of " ^ v x ^ ", whose tag may be any of "
                                       ^ String.concatWith ", " (List.map Int.toString ts) ^ " here")
                     | NONE => bug (here () ^ ": " ^ what () ^ " of " ^ v x ^ ", where no test of its tag comes first"))
            | _ => ()

          fun instr (here, live, facts) i =
            case i of
              Def (x, oper) =>
                (case oper of
                   Select (k, y) =>
                     (subject (here, fn () => "a Select of field " ^ Int.toString k, y, fn Tup n => k < n | _ => false);
                      case makesOf (y) of
                        SOME (Tuple parts) =>
                          if k < List.length parts then agreeing (here, x, sh (List.nth (parts, k)), fn () => "field " ^ Int.toString k ^ " of " ^ v y)
                          else ()
                      | _ => ())
                 | Field (tag, k, y) =>
                     (subject (here, fn () => "a Field of constructor " ^ Int.toString tag, y,
                               fn Data st =>
                                    (case fieldsOf (st, tag) of
                                       SOME n =>
                                         if k < n andalso n > 1 then true
                                         else bug (here () ^ ": field " ^ Int.toString k ^ " of constructor " ^ Int.toString tag
                                                   ^ " of datatype " ^ Int.toString st ^ " read from " ^ v y ^ ", which the program makes of "
                                                   ^ Int.toString n ^ (if n = 1 then " field, its argument boxed" else " fields"))
                                     | NONE => true)
                                | _ => false);
                      tagged (here, live, fn () => "a Field of constructor " ^ Int.toString tag, y, tag, facts);
                      case sh y of
                        Data st =>
                          (case declared (st, tag) of
                             SOME fs => if k < List.length fs
                                        then agreeing (here, x, List.nth (fs, k), fn () => "field " ^ Int.toString k ^ " of constructor "
                                                                                          ^ Int.toString tag ^ " of datatype " ^ Int.toString st
                                                                                          ^ " as it is declared")
                                        else ()
                           | NONE => ())
                      | _ => ();
                      case makesOf (y) of
                        SOME (Con (tag', parts)) =>
                          if tag = tag' andalso k < List.length parts
                          then agreeing (here, x, sh (List.nth (parts, k)), fn () => "field " ^ Int.toString k ^ " of " ^ v y)
                          else ()
                      | _ => ())
                 | Decon (tag, y) =>
                     (subject (here, fn () => "a Decon of constructor " ^ Int.toString tag, y,
                               fn Data st =>
                                    (case fieldsOf (st, tag) of
                                       SOME 1 => true
                                     | SOME n => bug (here () ^ ": the argument of constructor " ^ Int.toString tag ^ " of datatype "
                                                      ^ Int.toString st ^ " taken whole from " ^ v y ^ ", which the program makes of "
                                                      ^ Int.toString n ^ " fields, laid out flat")
                                     | NONE => true)
                                | _ => false);
                      tagged (here, live, fn () => "a Decon of constructor " ^ Int.toString tag, y, tag, facts);
                      case sh y of
                        Data st =>
                          (case declared (st, tag) of
                             SOME [a] => agreeing (here, x, a, fn () => "the argument of constructor " ^ Int.toString tag ^ " of datatype "
                                                                      ^ Int.toString st ^ " as it is declared")
                           | _ => ())
                      | _ => ())
                 | Con (tag, vs) =>
                     (case sh x of
                        Data st =>
                          (case declared (st, tag) of
                             SOME fs => if List.length fs = List.length vs
                                        then ignore (ListPair.foldl (fn (y, a, k) =>
                                                                       (agreeing (here, y, a, fn () => "field " ^ Int.toString k ^ " of constructor "
                                                                                                    ^ Int.toString tag ^ " of datatype " ^ Int.toString st
                                                                                                    ^ " as it is declared");
                                                                        k + 1)) 0 (vs, fs))
                                        else ()
                           | NONE => ())
                      | _ => ())
                 | ConTag y => subject (here, fn () => "a ConTag", y, isData)
                 | Call (fv, _) => subject (here, fn () => "a Call", fv, fn Clo => true | _ => false)
                 | CallK (g, xs) => callee (here, g, xs)
                 | Closure (g, vs) =>
                     ignore (List.foldl (fn (SOME y, k) => (captured (here, g, k, y); k + 1) | (NONE, k) => k + 1) 0 vs)
                 | SetEnv (c, k, y) => (case makesOf (c) of SOME (Closure (g, _)) => captured (here, g, k, y) | _ => ())
                 | _ => ())
            | _ => ()

          fun block (i, {label, params, instrs, transfer} : block) =
            let
              fun here () = named f ^ ", b" ^ Int.toString label
              (* what holds where it begins: nothing at the function's
                 entry, at a handler's block (its region may raise anywhere)
                 or where no way in was seen; a parameter's tags, where every
                 jump into it says *)
              val facts = case Array.sub (entries, i) of SOME m => m | NONE => nothing
              val facts =
                case Array.sub (paramTags, i) of
                  SOME ts =>
                    if Array.sub (backInto, i) then facts
                    else {tags = ListPair.foldl (fn (p, SOME t, m) => IntMap.insert (m, p, t) | (_, NONE, m) => m) (#tags facts) (params, ts),
                          eqs = #eqs facts}
                | NONE => facts
              val live = Array.sub (reached, i)
              val () = List.app (instr (here, live, facts)) instrs
              fun argTags xs = SOME (List.map (fn x => known (facts, x)) xs)
              fun goto (l, xs, facts') = case blockOf l of SOME j => arrive (i, j, facts', argTags xs) | NONE => ()
              fun edge (l, facts') = case blockOf l of SOME j => arrive (i, j, facts', NONE) | NONE => ()
              (* a test of tags: If on imm_eq of a ConTag of y and a constant,
                 or of the ConTags of two values *)
              fun tagTest c =
                case makesOf (c) of
                  SOME (Prim (eq, [a, b])) =>
                    if eq = "imm_eq" orelse eq = "poly_eq" orelse eq = "int_eq" then
                      let
                        fun parts (t, k) =
                          case (makesOf (t), makesOf (k)) of
                            (SOME (ConTag y), SOME (Const (Lambda.CInt n))) =>
                              if IntInf.>= (n, IntInf.fromInt 0) andalso IntInf.< (n, IntInf.fromInt 65536)
                              then SOME (OfTag (y, IntInf.toInt n)) else NONE
                          | (SOME (ConTag y), SOME (ConTag z)) => SOME (Same (y, z))
                          | _ => NONE
                      in case parts (a, b) of SOME r => SOME r | NONE => parts (b, a) end
                    else NONE
                | _ => NONE
            in
              case transfer of
                Goto (l, xs) =>
                  (case blockOf l of
                     SOME j =>
                       (args (here, xs, #params (Vector.sub (bv, j)), sh, fn k => "parameter " ^ Int.toString k ^ " of b" ^ Int.toString l);
                        goto (l, xs, facts))
                   | NONE => ())
              | If (c, a, b) =>
                  (case tagTest c of
                     SOME (OfTag (y, t)) => (edge (a, narrow (facts, y, fn ts => List.filter (fn u => u = t) ts));
                                             edge (b, narrow (facts, y, fn ts => without (ts, [t]))))
                   | SOME (Same (y, z)) => (edge (a, equate (facts, y, z)); edge (b, facts))
                   | NONE => (edge (a, facts); edge (b, facts)))
              | IfTag (y, t, a, b) =>
                  (subject (here, fn () => "an IfTag", y, isData);
                   edge (a, narrow (facts, y, fn ts => List.filter (fn u => u = t) ts));
                   edge (b, narrow (facts, y, fn ts => without (ts, [t]))))
              | Switch (y, cases, d) =>
                  (subject (here, fn () => "a Switch", y, isData);
                   List.app (fn (t, l) => edge (l, narrow (facts, y, fn ts => List.filter (fn u => u = t) ts))) cases;
                   edge (d, narrow (facts, y, fn ts => without (ts, List.map #1 cases))))
              | TailCallK (g, xs) => callee (here, g, xs)
              | TailCall (fv, _) => subject (here, fn () => "a TailCall", fv, fn Clo => true | _ => false)
              | _ => ()
            end
          (* the loops' heads and the handlers' blocks *)
          val () = Vector.appi (fn (i, {instrs, transfer, ...} : block) =>
                                  (List.app (fn Push h => (case blockOf h of SOME j => Array.update (backInto, j, true) | NONE => ())
                                              | _ => ()) instrs;
                                   List.app (fn l => case blockOf l of SOME j => if j <= i then Array.update (backInto, j, true) else ()
                                                                     | NONE => ())
                                            (succs transfer)))
                               bv
          (* a handler's block is reached where a reached block pushes it *)
          fun pushes i =
            List.app (fn Push h => (case blockOf h of SOME j => if Array.sub (reached, i) then Array.update (reached, j, true) else ()
                                                     | NONE => ())
                       | _ => ()) (#instrs (Vector.sub (bv, i)))
          val () = Vector.appi (fn (i, b) =>
                                  (if Array.sub (backInto, i) then Array.update (entries, i, SOME nothing) else ();
                                   block (i, b);
                                   pushes i))
                               bv
        in
          ()
        end
    in
      List.app func p;
      Pass.tally ("shaped", !shaped);
      Pass.tally ("unshaped", !unshaped)
    end

  fun check (p : program) : unit =
    checkWith (fn id => case IntTable.find (!Lower.lastTys, id) of
                          SOME r => let val a = !r in fn x => if x >= 0 andalso x < Array.length a then Array.sub (a, x) else NONE end
                        | NONE => fn _ => NONE)
              p

  (* after lower, beside LowLint, at its level *)
  fun stage (p : program) : unit =
    case level () of
      SOME l => Pass.checkAt ("shapes", l) check p
    | NONE => ()
end
