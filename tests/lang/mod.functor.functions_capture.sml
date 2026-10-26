(* --functors=functions in units: a functor's function is kept in its unit,
   and a closure in it may hold a tuple nothing uses that Simplify's last
   round left (temp' put in temp: the parameter `(ty, A.empty)`), of a
   variable the closure would capture only for it. Lower does not make that
   tuple, so the closure must not capture the variable (Lower.free; the lint
   of Low: "env 0 is captured and never read"). Found in MLton's
   llvm-codegen.fun, compiled in units under --lint. *)
signature ATTRS = sig type t val empty : t val other : t end
functor Gen2 (A : ATTRS) = struct
  fun out (chunk : int list) =
    let
      local
        val c = ref 0
        fun next () = (c := !c + 1; !c)
      in
        fun temp' (param as (ty, _)) = let val name = "%t" ^ Int.toString (next ()) in ((name, param), (name, ty)) end
        fun temp ty = #2 (temp' (ty, A.empty))
      end
      fun use {temp, args} = String.concat (List.map (fn a => #1 (temp a)) args)
      val ((p, _), _) = temp' (0, A.other)
    in p ^ use {temp = temp, args = chunk} ^ use {temp = temp, args = List.rev chunk} end
end
structure G2 = Gen2 (struct type t = string val empty = "" val other = "o" end)
val () = print (G2.out [1, 2, 3] ^ "\n")
