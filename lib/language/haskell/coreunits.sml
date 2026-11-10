(* Core in units (the haskell98 roadmap's M21): units joined into one
   program. A type is the same in two units where its declaration prints
   the same, and an import is at its definition's type where the types
   print the same, since an interface gives a client the exporter's
   declaration and type as they are (HsIface). *)
structure CoreUnits :> CORE_UNITS =
struct
  open Core

  exception Error of string

  fun declText d = CoreText.show [d]

  fun join (units : program list) : program =
    let
      val all = List.concat units
      (* the values the units define, with their types *)
      val defined = List.foldl (fn (Val (x, t, _), m) => CoreMap.insert (m, x, t) | (_, m) => m) CoreMap.empty all
      fun keep (d, (types, acc)) =
        case d of
          Import (x, t) =>
            (case CoreMap.find (defined, x) of
               NONE => (types, d :: acc)
             | SOME u =>
                 if CoreText.showTy t = CoreText.showTy u then (types, acc)
                 else raise Error ("the import of " ^ x ^ " is at " ^ CoreText.showTy t ^ ", and its definition at "
                                   ^ CoreText.showTy u))
        | Val _ => (types, d :: acc)
        | _ =>
            let
              val t = case d of Data (t, _, _) => t | Newtype (t, _, _, _) => t | _ => ""
              val text = declText d
            in
              case CoreMap.find (types, t) of
                NONE => (CoreMap.insert (types, t, text), d :: acc)
              | SOME first =>
                  if first = text then (types, acc)
                  else raise Error ("the type " ^ t ^ " is declared apart by two units:\n" ^ first ^ "and\n" ^ text)
            end
    in List.rev (#2 (List.foldl keep (CoreMap.empty, []) all)) end

  (* the type constructors a type mentions *)
  fun tyCons (t : ty, acc : string list) : string list =
    case t of
      TVar _ => acc
    | TCon c => c :: acc
    | TApp (a, b) => tyCons (a, tyCons (b, acc))
    | TFun (a, b) => tyCons (a, tyCons (b, acc))
    | TForall (_, _, b) => tyCons (b, acc)
    | TEval a => tyCons (a, acc)
    | TUTuple ts => List.foldl tyCons acc ts

  (* the types a declaration mentions, and its name *)
  fun mentions (d : decl) : string list =
    case d of
      Data (_, _, cons) => List.foldl (fn ((_, fs), acc) => List.foldl tyCons acc fs) [] cons
    | Newtype (_, _, _, f) => tyCons (f, [])
    | Val (_, t, _) => tyCons (t, [])
    | Import (_, t) => tyCons (t, [])
  fun nameOf (d : decl) : string =
    case d of Data (t, _, _) => t | Newtype (t, _, _, _) => t | Val (x, _, _) => x | Import (x, _) => x
  fun isType (d : decl) : bool = case d of Data _ => true | Newtype _ => true | _ => false

  fun member (x : string, xs : string list) = List.exists (fn y => y = x) xs
  fun distinct (xs : string list) : string list =
    List.rev (List.foldl (fn (x, acc) => if member (x, acc) then acc else x :: acc) [] xs)
  fun insertSorted (x : string, []) = [x]
    | insertSorted (x, y :: ys) = if x <= y then x :: y :: ys else y :: insertSorted (x, ys)
  fun sort (xs : string list) : string list = List.foldl insertSorted [] xs

  fun interface (p : program, exports : string list) : program =
    let
      val types = List.foldl (fn (d, m) => if isType d then CoreMap.insert (m, nameOf d, d) else m) CoreMap.empty p
      val values = List.filter (fn d => case d of Val (x, _, _) => member (x, exports) | Import (x, _) => member (x, exports)
                                                | _ => false) p
      fun reach ([], seen) = seen
        | reach (t :: rest, seen) =
            if member (t, seen) then reach (rest, seen)
            else case CoreMap.find (types, t) of
                   SOME d => reach (mentions d @ rest, t :: seen)
                 | NONE => reach (rest, seen)
      val roots = List.filter (fn x => CoreMap.member (types, x)) exports @ List.concat (List.map mentions values)
      val reached = reach (roots, [])
    in
      List.filter (fn d => isType d andalso member (nameOf d, reached)) p
      @ List.map (fn Val (x, t, _) => Import (x, t) | d => d) values
    end

  fun fingerprints (hash : string -> string) (iface : program) : (string * string) list =
    let
      val typeDecls = List.filter isType iface
      val types = List.foldl (fn (d, m) => CoreMap.insert (m, nameOf d, d)) CoreMap.empty typeDecls
      fun edges t = case CoreMap.find (types, t) of SOME d => List.filter (fn u => CoreMap.member (types, u)) (distinct (mentions d))
                                                  | NONE => []
      (* the recursive groups of the types (Tarjan), each after the groups it
         mentions *)
      val index = ref (CoreMap.empty : int CoreMap.map)
      val low = ref (CoreMap.empty : int CoreMap.map)
      val onStack = ref (CoreMap.empty : bool CoreMap.map)
      fun isOnStack w = CoreMap.find (!onStack, w) = SOME true
      val stack = ref ([] : string list)
      val counter = ref 0
      val groups = ref ([] : string list list)
      fun lowOf v = valOf (CoreMap.find (!low, v))
      fun setLow (v, n) = low := CoreMap.insert (!low, v, n)
      fun visit v =
        let
          val () = (index := CoreMap.insert (!index, v, !counter); setLow (v, !counter); counter := !counter + 1;
                    stack := v :: !stack; onStack := CoreMap.insert (!onStack, v, true))
          val () =
            List.app (fn w =>
                        case CoreMap.find (!index, w) of
                          NONE => (visit w; setLow (v, Int.min (lowOf v, lowOf w)))
                        | SOME i => if isOnStack w then setLow (v, Int.min (lowOf v, i)) else ())
                     (edges v)
        in
          if lowOf v = valOf (CoreMap.find (!index, v)) then
            let
              fun pop acc =
                case !stack of
                  w :: rest => (stack := rest; onStack := CoreMap.insert (!onStack, w, false);
                                if w = v then w :: acc else pop (w :: acc))
                | [] => acc
            in groups := pop [] :: !groups end
          else ()
        end
      val () = List.app (fn d => if CoreMap.member (!index, nameOf d) then () else visit (nameOf d)) typeDecls
      (* Tarjan gives a group after every group it reaches *)
      val ordered = List.rev (!groups)
      val prints = ref (CoreMap.empty : string CoreMap.map)
      fun printOf t = case CoreMap.find (!prints, t) of SOME f => f | NONE => t
      fun outside (names : string list, ms : string list) : string =
        String.concatWith "\000" (List.map (fn u => u ^ "=" ^ printOf u)
                                           (sort (List.filter (fn u => not (member (u, names))) (distinct ms))))
      val () =
        List.app (fn g =>
                    let
                      val ds = List.map (fn t => valOf (CoreMap.find (types, t))) g
                      val text = String.concat (sort (List.map declText ds))
                      val f = hash ("type\000" ^ text ^ "\000" ^ outside (g, List.concat (List.map mentions ds)))
                    in List.app (fn t => prints := CoreMap.insert (!prints, t, f)) g end)
                 ordered
    in
      List.map (fn d =>
                  if isType d then (nameOf d, printOf (nameOf d))
                  else
                    let val t = case d of Val (_, t, _) => t | Import (_, t) => t | _ => raise Fail "CoreUnits: a type"
                    in (nameOf d, hash ("value\000" ^ CoreText.showTy t ^ "\000" ^ outside ([], tyCons (t, [])))) end)
               iface
    end

  fun uses (d : decl) : {values : string list, types : string list, cons : string list} =
    let
      val values = ref ([] : string list)
      val types = ref ([] : string list)
      val cons = ref ([] : string list)
      fun ty t = types := tyCons (t, !types)
      fun bind (bound, x) = CoreMap.insert (bound, x, ())
      fun atom bound (Var x) = if CoreMap.member (bound, x) then () else values := x :: !values
        | atom _ (Lit _) = ()
      fun exp bound e =
        case e of
          Atom a => atom bound a
        | App (f, args) => (exp bound f; List.app (fn TyArg t => ty t | ValArg a => atom bound a) args)
        | Lam (bs, body) =>
            (List.app (fn ValBinder (_, t) => ty t | TyBinder _ => ()) bs;
             exp (List.foldl (fn (ValBinder (x, _), m) => bind (m, x) | (_, m) => m) bound bs) body)
        | Let (x, t, rhs, body) => (ty t; exp bound rhs; exp (bind (bound, x)) body)
        | LetRec (bs, body) =>
            let val bound' = List.foldl (fn ((x, _, _), m) => bind (m, x)) bound bs
            in List.app (fn (_, t, rhs) => (ty t; exp bound' rhs)) bs; exp bound' body end
        | Case (scrut, b, alts) => (exp bound scrut; List.app (alt (bind (bound, b))) alts)
        | Con (c, ts, atoms) => (cons := c :: !cons; List.app ty ts; List.app (atom bound) atoms)
        | Prim (_, ts, atoms) => (List.app ty ts; List.app (atom bound) atoms)
        | UTuple atoms => List.app (atom bound) atoms
        | Cast (e, t) => (ty t; exp bound e)
      and alt bound a =
        case a of
          AltCon (c, xs, rhs) => (cons := c :: !cons; exp (List.foldl (fn (x, m) => bind (m, x)) bound xs) rhs)
        | AltLit (_, rhs) => exp bound rhs
        | AltUTuple (xs, rhs) => exp (List.foldl (fn (x, m) => bind (m, x)) bound xs) rhs
        | AltDefault rhs => exp bound rhs
      val () =
        case d of
          Data (_, _, cs) => List.app (fn (_, fs) => List.app ty fs) cs
        | Newtype (_, _, _, f) => ty f
        | Val (_, t, e) => (ty t; exp CoreMap.empty e)
        | Import (_, t) => ty t
    in {values = distinct (List.rev (!values)), types = distinct (List.rev (!types)), cons = distinct (List.rev (!cons))} end

  fun unresolved (p : program) : string list =
    let val defined = List.foldl (fn (Val (x, _, _), m) => CoreMap.insert (m, x, ()) | (_, m) => m) CoreMap.empty p
    in List.mapPartial (fn Import (x, _) => if CoreMap.member (defined, x) then NONE else SOME x | _ => NONE) p end
end
