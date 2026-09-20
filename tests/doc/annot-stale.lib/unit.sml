(* One value.

   Area: Tests *)
signature UNIT =
sig
  (* The value. *)
  val it : unit
end

(* Implements: UNIT *)
structure Unit =
struct
  val it = ()
  val extra = ()
end
