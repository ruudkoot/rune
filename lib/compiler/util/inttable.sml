(* Mutable tables from ints to values, by hashing: for a pass that sets and
   asks by key and never lists what a table holds -- so the order a table
   keeps, which is not its keys', cannot reach the output (the builds must
   emit the same bytecode; see ordmap.sml). The keys are stamps, which are
   dense, so the hash is the key itself. *)
signature INT_TABLE =
sig
  type 'a table
  (* Backing storage at an ownership boundary. Capture again after mutations
     before switching owners; this retains live binding-cell identities. *)
  type 'a storage
  (* an empty table, for about this many keys *)
  val table : int -> 'a table
  (* A copy owns its buckets and binding cells; stored values retain their identities. *)
  val copy : 'a table -> 'a table
  (* Restore dst from src without sharing buckets or binding cells. *)
  val restore : 'a table * 'a table -> unit
  (* Save backing storage without copying it. *)
  val saveStorage : 'a table -> 'a storage
  (* Restore an owner's backing storage and size. *)
  val restoreStorage : 'a table * 'a storage -> unit
  val find : 'a table * int -> 'a option
  (* the key's value set, whether it had one or not *)
  val insert : 'a table * int * 'a -> unit
  (* the key's value set to what f makes of the one it had, or of NONE: one
     look for the key, where find and insert are two *)
  val update : 'a table * int * ('a option -> 'a) -> unit
  (* a count kept in the table: one more *)
  val bump : int table * int -> unit
  (* every key from lo up to hi, but not hi, taken out *)
  val removeRange : 'a table * int * int -> unit
  (* a table of its own of the keys from lo up to hi, but not hi, and their
     values *)
  val copyRange : 'a table * int * int -> 'a table
end

structure IntTable :> INT_TABLE =
struct
  type 'a table = {buckets : (int * 'a ref) list array ref, count : int ref}
  type 'a storage = (int * 'a ref) list array * int

  fun table n =
    let
      fun pow2 s = if s >= n then s else pow2 (2 * s)
    in
      {buckets = ref (Array.array (pow2 16, [])), count = ref 0}
    end

  fun copy ({buckets, count} : 'a table) : 'a table =
    {buckets = ref (Array.tabulate (Array.length (!buckets), fn i =>
       List.map (fn (k, cell) => (k, ref (!cell))) (Array.sub (!buckets, i)))), count = ref (!count)}

  fun restore ({buckets, count} : 'a table, source : 'a table) =
    let val cloned = copy source
    in buckets := !(#buckets cloned); count := !(#count cloned) end

  fun saveStorage ({buckets, count} : 'a table) : 'a storage = (!buckets, !count)
  fun restoreStorage ({buckets, count} : 'a table, (saved, size) : 'a storage) =
    (buckets := saved; count := size)

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

  (* key by key where the range is the smaller, else bucket by bucket *)
  fun removeRange ({buckets, count} : 'a table, lo, hi) =
    let
      val b = !buckets
      fun out i =
        let
          val (gone, kept) = List.partition (fn (k, _) => k >= lo andalso k < hi) (Array.sub (b, i))
        in
          case gone of
            [] => ()
          | _ => (Array.update (b, i, kept); count := !count - List.length gone)
        end
      fun keys k = if k >= hi then () else (out (slot (b, k)); keys (k + 1))
      fun all i = if i >= Array.length b then () else (out i; all (i + 1))
    in
      if hi <= lo then () else if hi - lo < Array.length b then keys lo else all 0
    end

  (* key by key where the range is the smaller, else bucket by bucket *)
  fun copyRange (source as {buckets, ...} : 'a table, lo, hi) : 'a table =
    let
      val t = table 16
      val b = !buckets
      fun bucket i = List.app (fn (k, cell) => if k >= lo andalso k < hi then insert (t, k, !cell) else ()) (Array.sub (b, i))
      fun keys k = if k >= hi then () else ((case find (source, k) of SOME v => insert (t, k, v) | NONE => ()); keys (k + 1))
      fun all i = if i >= Array.length b then () else (bucket i; all (i + 1))
    in
      (if hi <= lo then () else if hi - lo < Array.length b then keys lo else all 0); t
    end
end
