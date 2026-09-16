(* Pattern-matrix usefulness. Families travel with explicit heads, so recursive
   datatypes require no unfolding of types. Each recursive specialization removes
   a pattern head. Limits bound pathological product/match combinations. *)
structure Match =
struct
  datatype key = Data of int | Tuple of int | Unit | Boolean of bool
               | Integer of IntInf.int | String of string
  datatype family = Fixed of (key * int) list | Constructors of int list ref
  datatype pat = Any | Head of key * pat list * family option
  fun sameKey (Data a,Data b) = a = b
    | sameKey (Tuple a,Tuple b) = a = b
    | sameKey (Unit,Unit) = true
    | sameKey (Boolean a,Boolean b) = a = b
    | sameKey (Integer a,Integer b) = IntInf.eq (a,b)
    | sameKey (String a,String b) = String.compare (a,b) = EQUAL
    | sameKey _ = false
  fun normalize tick (Core.P (p,t,node)) = (tick (); case node of
      Core.Bind _ => Any | Core.Wildcard => Any
    | Core.UnitPattern => Head (Unit,[],SOME (Fixed [(Unit,0)]))
    | Core.BooleanPattern b => Head (Boolean b,[],SOME (Fixed [(Boolean false,0),(Boolean true,0)]))
    | Core.IntegerPattern n => Head (Integer n,[],NONE)
    | Core.StringPattern s => Head (String s,[],NONE)
    | Core.TuplePattern ps => Head (Tuple (List.length ps),List.map (normalize tick) ps,
                                   SOME (Fixed [(Tuple (List.length ps),List.length ps)]))
    | Core.ConstructorPattern (id,arg) =>
        let val ids = case Types.root p t of
                Types.TData (Types.TypeConstructor {constructors,...},_) => constructors
              | _ => Source.fail p "internal" "constructor pattern without datatype"
        in Head (Data id,case arg of NONE => [] | SOME a => [normalize tick a],
                 SOME (Constructors ids)) end)
  fun check p warnMissing patterns =
    let
      val work = ref 0
      fun tick () = (work := !work+1; if !work > 1000000 then
          Source.fail p "limit" "match analysis exceeds 1000000 steps" else ())
      fun anys n = List.tabulate (n,fn _ => (tick (); Any))
      fun append xs rest = List.foldr (fn (x,acc) => (tick (); x::acc)) rest xs
      fun members (Fixed xs) = xs
        | members (Constructors ids) = List.map (fn n => (tick (); (Data n,n mod 2))) (!ids)
      fun specialize key arity rows = List.mapPartial (fn row => (tick (); case row of
            Any::rest => SOME (append (anys arity) rest)
          | Head (k,args,_)::rest => if sameKey (k,key) then SOME (append args rest) else NONE
          | [] => NONE)) rows
      fun defaults rows = List.mapPartial (fn row => (tick (); case row of
          Any::rest => SOME rest | _ => NONE)) rows
      fun useful depth rows query =
        (tick (); if depth > 512 then Source.fail p "limit" "match analysis exceeds depth 512" else ();
        case query of [] => List.null rows
         | Head (key,args,_)::rest =>
             useful (depth+1) (specialize key (List.length args) rows) (append args rest)
         | Any::rest =>
             List.null rows orelse let
               val heads = List.mapPartial (fn row => (tick (); case row of
                   Head (k,_,family)::_ => SOME (k,family) | _ => NONE)) rows
               val family = case heads of (_,SOME xs)::_ => SOME (members xs) | _ => NONE
               fun present key = List.exists (fn (k,_) => (tick (); sameKey (k,key))) heads
             in case family of
                 SOME xs => if List.all (fn (k,_) => present k) xs then
                   List.exists (fn (key,arity) => useful (depth+1)
                       (specialize key arity rows) (append (anys arity) rest)) xs
                   else useful (depth+1) (defaults rows) rest
               | NONE => useful (depth+1) (defaults rows) rest
             end)
      fun loop rows [] = rows
        | loop rows (pat::rest) =
            let val normalized = normalize tick pat
                val Core.P (pos,_,_) = pat
                val () = if useful 0 rows [normalized] then ()
                         else Source.warn pos "redundant match clause"
            in loop ([normalized]::rows) rest end
      val rows = loop [] patterns
    in if warnMissing andalso useful 0 rows [Any] then
         Source.warn p "non-exhaustive match" else () end
end
