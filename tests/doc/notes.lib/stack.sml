(* Stacks.

   Area: Tests

   Erratum: `STACK/page`. The page calls it a queue. *)
signature STACK =
sig
  (* The type of stacks.

     Implementation: `Stack.t/list`. A list, the top first. *)
  type t

  (* The empty stack. *)
  val empty : t

  (* `push (s, x)` is `s` with `x` on top.

     Reading: `Stack.push/returns-new`. "Adds x" is read as returning a new stack.

     Reading (the suite differs): `Stack.push/full`. A stack is never full here.

     Pinned by: `Stack.push/full-*` *)
  val push : t * int -> t

  (* `pop s` is `s` without its top.

     Limitation: `Stack.pop/empty`. The empty stack is returned as it is. *)
  val pop : t -> t
end

(* Implements: STACK *)
structure Stack =
struct
  type t = int list
  val empty = []
  fun push (s, x) = x :: s
  (* Deviation: `Stack.pop/no-exception`. The specification wants an exception. *)
  fun pop s = case s of [] => [] | _ :: r => r
end
