(* One value.

   Area: Tests *)
signature UNIT =
sig
  (* The value. *)
  val it : unit

  (* The value again. *)
  val again : unit
end

(* Implements: UNIT *)
structure Unit =
struct
  val it = ()
  val again = ()
  val extra = ()
end
