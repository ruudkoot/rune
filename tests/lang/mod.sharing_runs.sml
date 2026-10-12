(* A run of sharing specifications, realised at once: classes of types
   that later equations merge, an equality type that makes its class
   admit equality, structures shared, and a chain of where type. *)
signature T = sig type t type u val show : t -> string end
signature S =
sig
  type a
  type b
  eqtype c
  type d
  structure P : T
  structure Q : T
  sharing type b = a
  sharing type c = b              (* the class of a and b admits equality now *)
  sharing type d = P.t
  sharing P = Q                   (* P.t = Q.t and P.u = Q.u *)
  sharing type Q.t = a            (* the classes of d and of a merge *)
  val mk : int -> a
  val toD : c -> d
end
functor F (X : S) =
struct
  (* every type of the class is one and admits equality *)
  fun same (x : X.a, y : X.d) = x = y
  fun twice (x : X.b) : X.c = x
  val s = X.P.show (X.toD (twice (X.mk 4)))
  val e = same (X.mk 1, X.toD (X.mk 1))
end
structure Impl =
struct
  type a = int type b = int type c = int type d = int
  structure P = struct type t = int type u = string fun show n = "P" ^ Int.toString n end
  structure Q = P
  fun mk n = n * 10
  fun toD n = n + 1
end
structure R = F (Impl)
val () = print (R.s ^ " " ^ Bool.toString R.e ^ "\n")

(* the clauses of a chain of where's, the innermost first *)
signature W = sig type t type u type v val f : t * u -> v end
  where type t = int and type u = string
  where type v = bool
structure V : W = struct type t = int type u = string type v = bool fun f (n, s) = n = size s end
val () = print (Bool.toString (V.f (3, "abc")) ^ "\n")
