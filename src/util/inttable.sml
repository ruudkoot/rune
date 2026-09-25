(* Mutable tables from ints to values, by hashing: for a pass that sets and
   asks by key and never lists what a table holds -- so the order a table
   keeps, which is not its keys', cannot reach the output (the builds must
   emit the same bytecode; see ordmap.sml). The keys are stamps, which are
   dense, so the hash is the key itself. *)
signature INT_TABLE =
sig
  type 'a table
  (* an empty table, for about this many keys *)
  val table : int -> 'a table
  val find : 'a table * int -> 'a option
  (* the key's value set, whether it had one or not *)
  val insert : 'a table * int * 'a -> unit
  (* the key's value set to what f makes of the one it had, or of NONE: one
     look for the key, where find and insert are two *)
  val update : 'a table * int * ('a option -> 'a) -> unit
  (* a count kept in the table: one more *)
  val bump : int table * int -> unit
end

structure IntTable :> INT_TABLE =
struct
  type 'a table = {buckets : (int * 'a ref) list array ref, count : int ref}

  fun table n =
    let
      fun pow2 s = if s >= n then s else pow2 (2 * s)
    in
      {buckets = ref (Array.array (pow2 16, [])), count = ref 0}
    end

  fun slot (buckets, k) = k mod Array.length buckets

  fun lookup ([], _) = NONE
    | lookup ((k', r) :: rest, k : int) = if k = k' then SOME r else lookup (rest, k)

  fun find ({buckets, ...} : 'a table, k) =
    case lookup (Array.sub (!buckets, slot (!buckets, k)), k) of
      SOME r => SOME (!r)
    | NONE => NONE

  (* twice the buckets once there are twice as many keys *)
  fun grow ({buckets, count} : 'a table) =
    if !count <= 2 * Array.length (!buckets) then ()
    else
      let
        val old = !buckets
        val new = Array.array (2 * Array.length old, [])
      in
        Array.app (List.app (fn e as (k, _) =>
                               let val i = slot (new, k) in Array.update (new, i, e :: Array.sub (new, i)) end))
                  old;
        buckets := new
      end

  fun insert (t as {buckets, count} : 'a table, k, v) =
    let val i = slot (!buckets, k)
    in
      case lookup (Array.sub (!buckets, i), k) of
        SOME r => r := v
      | NONE => (Array.update (!buckets, i, (k, ref v) :: Array.sub (!buckets, i)); count := !count + 1; grow t)
    end

  fun update (t as {buckets, count} : 'a table, k, f) =
    let val i = slot (!buckets, k)
    in
      case lookup (Array.sub (!buckets, i), k) of
        SOME r => r := f (SOME (!r))
      | NONE => (Array.update (!buckets, i, (k, ref (f NONE)) :: Array.sub (!buckets, i)); count := !count + 1; grow t)
    end

  fun bump (t, k) = update (t, k, fn SOME n => n + 1 | NONE => 1)
end
