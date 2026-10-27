(* A local function lifted to the top level (Lift, at -O1 and -O2) whose
   body declares a polymorphic function of its own: the lifted function
   abstracts over the type variables of the functions around it that it
   names free, never over the inner function's, which its calls could not
   give -- Mid is System F (docs/ir.md, What a Mid keeps; the linting
   roadmap's E10 and M5, results/E10/bugs/lift-tyvar.sml). *)
fun outer (x : int) =
  let
    fun lifted (y : int) =
      let fun poly z = (z, y)
      in #2 (poly "a") + #2 (poly 1.0) + (if y > 0 then lifted (y - 1) else x) end
  in lifted x end

(* the same, inside a polymorphic function, whose variable the lifted one
   names and the inner one does not *)
fun 'a around (v : 'a, n : int) : 'a list =
  let
    fun build k =
      let fun pair w = (w, v)
      in if k = 0 then [] else #2 (pair k) :: #2 (pair "b") :: build (k - 1) end
  in build n end

val () = print (Int.toString (outer 3) ^ " " ^ Int.toString (length (around (true, 2))) ^ " "
                ^ String.concat (around ("x", 1)) ^ "\n")
