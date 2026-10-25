(* --functors=functions: what the review of M6 found (docs/plans/functors-units.md,
   M6), each case a program that went wrong before its fix *)

(* 1. A test of the program's own against 0 whose first branch makes a
   constructor of a parameter's datatype with an open constructor is no
   descriptor's test: the expansion kept its first branch (1 0 200 100 was
   5 0 200 100). An open constructor's test is a primitive of its own
   (open_boxed). *)
functor OpenF (X : sig type s datatype t = C of s | E of int end) = struct
  fun f (n : int) = if n = 0 then X.E n else X.E 1
  fun g (n : int) = case n of 0 => X.E 100 | _ => X.E 200
end
structure OpenA = struct type s = int * int datatype t = C of s | E of int end
structure OpenFA = OpenF (OpenA)
fun show (OpenA.E k) = Int.toString k | show (OpenA.C (a, b)) = "C"
val () = print (show (OpenFA.f 5) ^ " " ^ show (OpenFA.f 0) ^ " " ^ show (OpenFA.g 7) ^ " " ^ show (OpenFA.g 0) ^ "\n")
functor OpenG (X : sig type s datatype t = C of s val mk : int -> s val get : s -> int end) = struct
  fun g (n : int, v : X.t) = if n = 0 then (case v of X.C u => X.get u) else ~1
  fun h (n : int) = if n = 0 then X.C (X.mk 7) else X.C (X.mk 8)
end
structure OpenB = struct type s = int * int datatype t = C of s fun mk n = (n, n) fun get (a, b) = a + b end
structure OpenGB = OpenG (OpenB)
val () = print (Int.toString (OpenGB.g (5, OpenB.C (1, 2))) ^ " " ^ Int.toString (OpenGB.g (0, OpenB.C (1, 2))) ^ " "
                ^ (case OpenGB.h 3 of OpenB.C (a, _) => Int.toString a) ^ "\n")

(* 2. An instance of a body's datatype passed to a functor whose parameter
   leaves the constructor's layout open: the descriptor was worked out from
   the layout the elaborator gave it (the body's, boxed), the expansion then
   laid the instance out flat, and the body's function made the
   constructor by the descriptor (a crash). The descriptor is the layout
   Lower gives the datatype (open_layout). *)
signature STALE_P = sig type u val mk : int -> u val get : u -> int end
signature STALE_Q = sig type u datatype 'a d = D of u | N of 'a val mk : int -> u end
functor StaleH (X : STALE_P) = struct datatype 'a d = D of X.u | N of 'a end
structure StaleA = struct type u = int * int fun mk n = (n, n + 1) fun get (a, b) = a * 100 + b end
structure StaleS = StaleH (StaleA)
functor StaleF (Y : STALE_Q) = struct
  val u0 = Y.mk 20
  val polyD = Y.D u0
  fun isD (Y.D _) = true | isD (Y.N _) = false
end
structure StaleT = StaleF (struct type u = StaleA.u datatype d = datatype StaleS.d val mk = StaleA.mk end)
val () = case (StaleT.polyD : int StaleS.d) of
           StaleS.D (a, b) => print (Int.toString a ^ " " ^ Int.toString b ^ "\n")
         | StaleS.N _ => print "N\n"
val () = print (Bool.toString (StaleT.isD (StaleS.D (1, 2))) ^ "\n")
(* the same through a copy of a body's datatype, boxed in the function
   where the descriptor is made, flat in the copy *)
functor StaleOuter (X : STALE_P) = struct
  datatype 'a e = D of X.u | N of 'a
  structure I = StaleF (struct type u = X.u datatype d = datatype e val mk = X.mk end)
  val v = case (I.polyD : int e) of D p => X.get p | N _ => ~1
end
structure StaleO = StaleOuter (StaleA)
val () = print (Int.toString StaleO.v ^ "\n")

(* 3. An instance an application in a body makes that its result does not
   show (I.b) kept its name in every copy of the body, and each copy
   entered it again with its own constructors (a lint failure; with a flat
   argument, the last copy's layout for all). Each copy has its own. *)
signature HIDDEN = sig type b val mk : int -> b val get : b -> int end
functor Hidden (X : sig type t val k : t val n : t -> int end) : HIDDEN =
struct
  datatype a = A of b | Z of X.t
  and b = B of a
  fun mk n = B (if n = 0 then Z X.k else A (mk (n - 1)))
  fun get (B (Z k)) = X.n k | get (B (A b)) = 1 + get b
end
functor Hides (Y : sig type t val k : t val n : t -> int end) : sig val run : int -> int end = struct
  structure I = Hidden (Y)
  fun run n = I.get (I.mk n)
end
structure H1 = Hides (struct type t = int val k = 10 fun n x = x end)
structure H2 = Hides (struct type t = string val k = "abc" val n = size end)
val () = print (Int.toString (H1.run 3) ^ " " ^ Int.toString (H2.run 4) ^ "\n")
functor HiddenFlat (X : sig type t val k : int -> t val n : t -> int end) : HIDDEN =
struct
  structure P :> sig type h val mk : X.t -> h val get : h -> X.t end = struct type h = X.t fun mk x = x fun get x = x end
  datatype b = B of P.h
  fun mk n = B (P.mk (X.k n))
  fun get (B h) = X.n (P.get h)
end
functor HidesFlat (Y : sig type t val k : int -> t val n : t -> int end) : sig val run : int -> int end = struct
  structure I = HiddenFlat (Y)
  fun run n = I.get (I.mk n)
end
structure H3 = HidesFlat (struct type t = string fun k n = Int.toString n val n = size end)
structure H4 = HidesFlat (struct type t = int * int fun k n = (n, n) fun n (a, b) = a + b end)
val () = print (Int.toString (H3.run 12345) ^ " " ^ Int.toString (H4.run 4) ^ "\n")
(* such an instance of an argument of no parameter's type, under a datatype
   of the body: the datatype is each copy's own too, as the instance is,
   and not one copy shared through what the parameter gives (MLton's whole
   compile, a lint failure of the fix above) *)
functor HiddenOf (X : sig type t val x : t end) = struct
  datatype b = B of X.t * int
  fun mk n = B (X.x, n)
  fun get (B (_, n)) = n
end
functor HidesUnder (Y : sig val k : int end) : sig val run : unit -> int end = struct
  structure I = HiddenOf (struct type t = string val x = "s" end)
  datatype e = E of I.b * I.b
  fun run () = case E (I.mk Y.k, I.mk 2) of E (a, b) => I.get a + I.get b
end
structure H5 = HidesUnder (struct val k = 1 end)
structure H6 = HidesUnder (struct val k = 5 end)
val () = print (Int.toString (H5.run () + 10 * H6.run ()) ^ "\n")

(* 5. A value of the program's own of the shape of an application's
   marker was taken for one (a compiler crash). A marker is a primitive
   of its own (functor_marker). *)
functor MarkF (X : sig val n : int end) = struct val m = X.n + 1 end
structure MarkA = MarkF (struct val n = 1 end)
val weird : (unit * unit) * (unit * unit) = RuneDynamic.cast ()
val () = print (Int.toString MarkA.m ^ "\n")

(* 6. A cast through unit and back at another type in the program's own
   code, what RuneDynamic.cast is for, failed MidLint's rule of a record's
   casts (D3), which holds of functor_cast alone. *)
fun viaUnit (x : int * int) =
  let val u : unit = RuneDynamic.cast x val back : int * string = RuneDynamic.cast u in #1 back end
val () = print (Int.toString (viaUnit (7, 8)) ^ "\n")
