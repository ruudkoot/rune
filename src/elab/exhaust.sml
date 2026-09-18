(* Exhaustiveness and redundancy of matches (Definition, Section 4.11), by
   the usefulness algorithm on pattern matrices (Maranget, "Warnings for
   pattern matching"): a rule is redundant when its patterns are not useful
   with respect to the rules before it, and a match is not exhaustive when a
   row of wildcards is useful with respect to all rules. Reports are
   warnings; the match compiler still emits the Match/Bind tests. *)
structure Exhaust =
struct
  open Ast

  (* Patterns reduced to what matters for coverage. Records and tuples are
     single constructors whose arity is the number of fields (in sorted label
     order); lists are the constructors nil and ::. *)
  datatype spat =
      Any
    | Con of coninfo * spat list         (* datatype constructor, argument as a one-element list *)
    | Const of scon                      (* special constants: an infinite domain *)
    | Rec of spat list
    | Ref of spat
    | Exn of exninfo * spat list         (* exception constructors: an open domain *)

  val nilInfo : coninfo = {name = "nil", tag = 0, hasArg = false, ncons = 2, isRef = false, siblings = [("nil", false), ("::", true)]}
  val consInfo : coninfo = {name = "::", tag = 1, hasArg = true, ncons = 2, isRef = false, siblings = [("nil", false), ("::", true)]}

  fun info (slot : patinfo option ref, sp) =
    case !slot of
      SOME i => i
    | NONE => Error.bug ("pattern not annotated at " ^ Source.describe sp)

  fun simplify (p : pat) : spat =
    case p of
      PWild _ => Any
    | PScon (sc, _) => Const sc
    | PVar (_, slot, sp) =>
        (case info (slot, sp) of
           PIVar _ => Any
         | PICon i => Con (i, [])
         | PIExn i => Exn (i, []))
    | PRecord (fields, flex, slot, sp) =>
        let
          val labels =
            if flex then
              (case !slot of
                 SOME t => (case Types.resolve t of
                              Types.TRecord fs => List.map #1 fs
                            | _ => Error.bug "flexible record pattern did not resolve to a record")
               | NONE => Error.bug ("flexible record pattern not annotated at " ^ Source.describe sp))
            else List.map #1 (Types.sortFields fields)
        in
          Rec (List.map (fn l => case List.find (fn (l', _) => l' = l) fields of
                                   SOME (_, p) => simplify p
                                 | NONE => Any) labels)
        end
    | PTuple (ps, _) => Rec (List.map simplify ps)
    | PList ([], _) => Con (nilInfo, [])
    | PList (p :: rest, sp) => Con (consInfo, [Rec [simplify p, simplify (PList (rest, sp))]])
    | PApp (_, slot, arg, sp) =>
        (case info (slot, sp) of
           PICon i => if #isRef i then Ref (simplify arg) else Con (i, [simplify arg])
         | PIExn i => Exn (i, [simplify arg])
         | PIVar _ => Error.bug "constructor application pattern annotated as variable")
    | PTyped (p, _, _) => simplify p
    | PLayered (_, _, p, _, _) => simplify p

  (* --- heads (constructors) of the first column --- *)
  datatype head =
      HCon of coninfo
    | HConst of scon
    | HRec of int
    | HRef
    | HExn of exninfo

  fun exnKey (i : exninfo) = case #builtin i of SOME k => ~(k + 1) | NONE => #stamp i

  fun sameHead (h1, h2) =
    case (h1, h2) of
      (HCon a, HCon b) => #tag a = #tag b
    | (HConst a, HConst b) => sconToString a = sconToString b
    | (HRec _, HRec _) => true
    | (HRef, HRef) => true
    | (HExn a, HExn b) => exnKey a = exnKey b
    | _ => false

  fun headOf (p : spat) : head option =
    case p of
      Any => NONE
    | Con (i, _) => SOME (HCon i)
    | Const sc => SOME (HConst sc)
    | Rec ps => SOME (HRec (List.length ps))
    | Ref _ => SOME HRef
    | Exn (i, _) => SOME (HExn i)

  fun arity (h : head) : int =
    case h of
      HCon i => if #hasArg i then 1 else 0
    | HConst _ => 0
    | HRec n => n
    | HRef => 1
    | HExn i => if #hasArg i then 1 else 0

  fun subpats (p : spat) : spat list =
    case p of
      Any => []
    | Con (_, args) => args
    | Const _ => []
    | Rec ps => ps
    | Ref a => [a]
    | Exn (_, args) => args

  fun anys n = List.tabulate (n, fn _ => Any)

  (* Distinct heads of the first column, in order of first appearance. *)
  fun heads (rows : spat list list) : head list =
    List.foldl (fn (row, acc) =>
                   case row of
                     p :: _ => (case headOf p of
                                  SOME h => if List.exists (fn h' => sameHead (h, h')) acc then acc else acc @ [h]
                                | NONE => acc)
                   | [] => acc) [] rows

  (* Does the set of heads cover the whole type? *)
  fun complete (hs : head list) : bool =
    case hs of
      [] => false
    | HCon i :: _ => List.length hs = #ncons i
    | HRec _ :: _ => true
    | HRef :: _ => true
    | HConst _ :: _ => false
    | HExn _ :: _ => false

  (* Specialisation by a head, and the default matrix. *)
  fun specialize (h : head, rows : spat list list) : spat list list =
    List.mapPartial (fn row =>
                        case row of
                          p :: rest =>
                            (case headOf p of
                               NONE => SOME (anys (arity h) @ rest)
                             | SOME h' => if sameHead (h, h') then SOME (subpats p @ rest) else NONE)
                        | [] => NONE) rows

  fun default (rows : spat list list) : spat list list =
    List.mapPartial (fn row => case row of Any :: rest => SOME rest | _ => NONE) rows

  (* Is the vector q useful with respect to the rows (can it match a value none of them matches)? *)
  fun useful (rows : spat list list, q : spat list) : bool =
    case q of
      [] => List.null rows
    | q1 :: qs =>
        (case headOf q1 of
           SOME h => useful (specialize (h, rows), subpats q1 @ qs)
         | NONE =>
             let val hs = heads rows
             in
               if complete hs then List.exists (fn h => useful (specialize (h, rows), anys (arity h) @ qs)) hs
               else useful (default rows, qs)
             end)

  (* A constructor of the same datatype that does not occur among the heads. *)
  fun missingCon (hs : head list) : spat =
    case hs of
      HCon i :: _ =>
        let
          fun find (_, []) = Any
            | find (t, (name, hasArg) :: rest) =
              if List.exists (fn HCon j => #tag j = t | _ => false) hs then find (t + 1, rest)
              else Con ({name = name, tag = t, hasArg = hasArg, ncons = #ncons i, isRef = false, siblings = #siblings i},
                        if hasArg then [Any] else [])
        in find (0, #siblings i) end
    | _ => Any

  (* A vector of n patterns matched by none of the rows, if any. *)
  fun missing (rows : spat list list, n : int) : spat list option =
    if n = 0 then (if List.null rows then SOME [] else NONE)
    else
      let val hs = heads rows
      in
        if complete hs then
          let
            fun try [] = NONE
              | try (h :: rest) =
                case missing (specialize (h, rows), arity h + n - 1) of
                  SOME v =>
                    let val k = arity h
                        val args = List.take (v, k)
                        val head =
                          case h of
                            HCon i => Con (i, args)
                          | HConst sc => Const sc
                          | HRec _ => Rec args
                          | HRef => Ref (List.hd args)
                          | HExn i => Exn (i, args)
                    in SOME (head :: List.drop (v, k)) end
                | NONE => try rest
          in try hs end
        else
          case missing (default rows, n - 1) of
            NONE => NONE
          | SOME rest => SOME (missingCon hs :: rest)
      end

  (* --- printing witnesses --- *)
  fun toString (p : spat) : string =
    case p of
      Any => "_"
    | Con (i, []) => #name i
    | Con (i, [Rec [a, b]]) => if #name i = "::" then atom a ^ " :: " ^ toString b else #name i ^ " " ^ atom (Rec [a, b])
    | Con (i, [a]) => #name i ^ " " ^ atom a
    | Con (i, _) => #name i
    | Const sc => sconToString sc
    | Rec ps => "(" ^ String.concatWith ", " (List.map toString ps) ^ ")"
    | Ref a => "ref " ^ atom a
    | Exn (i, []) => #name i
    | Exn (i, a :: _) => #name i ^ " " ^ atom a
  and atom p =
    case p of
      Con (_, _ :: _) => "(" ^ toString p ^ ")"
    | Exn (_, _ :: _) => "(" ^ toString p ^ ")"
    | Ref _ => "(" ^ toString p ^ ")"
    | _ => toString p

  fun witnessString (v : spat list) =
    case v of
      [w] => toString w
    | ws => String.concatWith " " (List.map atom ws)

  (* --- entry points --- *)
  fun checkRedundant (rows : spat list list, spans : Source.span list) : unit =
    let
      fun go (_, [], _) = ()
        | go (prev, row :: rest, sp :: sps) =
          (if useful (List.rev prev, row) then () else Error.warn (sp, "redundant match rule");
           go (row :: prev, rest, sps))
        | go _ = ()
    in go ([], rows, spans) end

  (* A match of rules (fn, case: exhaustive and irredundant; handle: irredundant only). *)
  fun checkMatch (pats : pat list, sp : Source.span, exhaustive : bool) : unit =
    let val rows = List.map (fn p => [simplify p]) pats
    in
      checkRedundant (rows, List.map spanOfPat pats);
      if exhaustive then
        case missing (rows, 1) of
          SOME v => Error.warn (sp, "match is not exhaustive (missing case: " ^ witnessString v ^ ")")
        | NONE => ()
      else ()
    end

  (* The clauses of a fun declaration: one column per argument. *)
  fun checkClauses (clauses : pat list list, spans : Source.span list, sp : Source.span) : unit =
    case clauses of
      [] => ()
    | first :: _ =>
        let val rows = List.map (List.map simplify) clauses
        in
          checkRedundant (rows, spans);
          case missing (rows, List.length first) of
            SOME v => Error.warn (sp, "match is not exhaustive (missing case: " ^ witnessString v ^ ")")
          | NONE => ()
        end

  (* A value binding pat = exp. *)
  fun checkBinding (p : pat, sp : Source.span) : unit =
    case missing ([[simplify p]], 1) of
      SOME v => Error.warn (sp, "binding is not exhaustive (missing case: " ^ witnessString v ^ ")")
    | NONE => ()
end
