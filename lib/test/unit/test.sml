(* Tests as values: the tree, its metadata, and the tests made of
   properties and golden files. *)
structure Test :> TEST =
struct
  type meta = {tags : string list, timeout : Time.time option, requires : string list,
               cpus : int option, memory : int option, pending : string option}
  val none : meta = {tags = [], timeout = NONE, requires = [], cpus = NONE, memory = NONE, pending = NONE}

  datatype 'a tree = Leaf of string * meta * 'a | Group of string * meta * 'a tree list
  type test = (unit -> unit) tree

  fun it name x = Leaf (name, none, x)
  fun describe name ts = Group (name, none, ts)

  fun withMeta f (Leaf (n, m, x)) = Leaf (n, f m, x)
    | withMeta f (Group (n, m, ts)) = Group (n, f m, ts)

  fun tag t = withMeta (fn {tags, timeout, requires, cpus, memory, pending} =>
                           {tags = tags @ [t], timeout = timeout, requires = requires, cpus = cpus, memory = memory,
                            pending = pending})
  fun timeout s = withMeta (fn {tags, timeout = _, requires, cpus, memory, pending} =>
                               {tags = tags, timeout = SOME s, requires = requires, cpus = cpus, memory = memory,
                                pending = pending})
  fun requires cs = withMeta (fn {tags, timeout, requires, cpus, memory, pending} =>
                                 {tags = tags, timeout = timeout, requires = requires @ cs, cpus = cpus,
                                  memory = memory, pending = pending})
  fun resources {cpus = c, memory = m} =
    withMeta (fn {tags, timeout, requires, cpus = _, memory = _, pending} =>
                 {tags = tags, timeout = timeout, requires = requires, cpus = SOME c, memory = SOME m, pending = pending})
  fun pending why = withMeta (fn {tags, timeout, requires, cpus, memory, pending = _} =>
                                 {tags = tags, timeout = timeout, requires = requires, cpus = cpus, memory = memory,
                                  pending = SOME why})

  fun pick (inner, outer) = case inner of NONE => outer | s => s

  (* the inner metadata over the outer: tags and requirements add up, the
     rest is the nearest's *)
  fun inherit (outer : meta, inner : meta) : meta =
    {tags = #tags outer @ #tags inner, timeout = pick (#timeout inner, #timeout outer),
     requires = #requires outer @ #requires inner, cpus = pick (#cpus inner, #cpus outer),
     memory = pick (#memory inner, #memory outer), pending = pick (#pending inner, #pending outer)}

  fun join ("", n) = n
    | join (p, "") = p
    | join (p, n) = p ^ "/" ^ n

  fun leaves t =
    let
      fun go (prefix, outer, Leaf (n, m, x), acc) = {path = join (prefix, n), meta = inherit (outer, m), leaf = x} :: acc
        | go (prefix, outer, Group (n, m, ts), acc) =
            List.foldl (fn (t, acc) => go (join (prefix, n), inherit (outer, m), t, acc)) acc ts
    in
      rev (go ("", none, t, []))
    end

  fun map f (Leaf (n, m, x)) = Leaf (n, m, f x)
    | map f (Group (n, m, ts)) = Group (n, m, List.map (map f) ts)

  fun ways ws t =
    let
      fun expand (Leaf (n, m, f)) = List.map (fn (wn, w) => tag ("way:" ^ wn) (Leaf (n ^ "[" ^ wn ^ "]", m, f w))) ws
        | expand (Group (n, m, ts)) = [Group (n, m, List.concat (List.map expand ts))]
    in
      case expand t of [x] => x | xs => Group ("", none, xs)
    end

  fun property name p =
    it name (fn () =>
               let val r = Check.check Check.default name (p ())
               in if Check.passed r then () else Expect.fail (Check.report name r) end)

  fun golden name {expected, actual} = it name (fn () => Golden.check (name, {expected = expected, actual = actual ()}))
end
