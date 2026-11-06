(* --functors=functions: a parameter's datatype that two specifications give,
   used through each. Sharing a structure with a view of it that has Operand
   but not Register (MLton's amd64-allocate-registers.sig) makes Operand.t one
   name whose Register takes amd64.Register.t in one specification and
   mlton.live.amd64.Register.t in the other: two types in the body, which
   every argument makes one. Built and taken apart through each, with
   Register.t a datatype, and abstract (an open constructor) laid out flat by
   one argument and boxed by another *)
signature PARTIAL = sig structure Operand : sig type t end end

signature DFULL =
sig
  structure Register : sig datatype t = T of int * int  val show : t -> string end
  structure Operand : sig datatype t = Register of Register.t | Imm of int end
end
signature DLIVE = sig structure amd64 : DFULL end
signature DMLT = sig structure amd64 : PARTIAL  structure live : DLIVE  sharing amd64 = live.amd64 end
signature DARGS = sig structure amd64 : DFULL  structure mlton : DMLT  sharing amd64 = mlton.amd64 end
functor D (S : DARGS) =
struct
  structure A = S.amd64
  structure L = S.mlton.live.amd64
  fun first (A.Operand.Register r) = "first " ^ A.Register.show r
    | first (A.Operand.Imm n) = "first Imm " ^ Int.toString n
  fun second (L.Operand.Register r) = "second " ^ L.Register.show r
    | second (L.Operand.Imm n) = "second Imm " ^ Int.toString n
  val viaFirst = A.Operand.Register (A.Register.T (1, 2))
  val viaSecond = L.Operand.Register (L.Register.T (3, 4))
  val register = L.Operand.Register
end

signature AFULL =
sig
  structure Register : sig type t  val make : int -> t  val show : t -> string end
  structure Operand : sig datatype t = Register of Register.t | Imm of int end
end
signature ALIVE = sig structure amd64 : AFULL end
signature AMLT = sig structure amd64 : PARTIAL  structure live : ALIVE  sharing amd64 = live.amd64 end
signature AARGS = sig structure amd64 : AFULL  structure mlton : AMLT  sharing amd64 = mlton.amd64 end
functor B (S : AARGS) =
struct
  structure A = S.amd64
  structure L = S.mlton.live.amd64
  fun first (A.Operand.Register r) = "first " ^ A.Register.show r
    | first (A.Operand.Imm n) = "first Imm " ^ Int.toString n
  fun second (L.Operand.Register r) = "second " ^ L.Register.show r
    | second (L.Operand.Imm n) = "second Imm " ^ Int.toString n
  val viaFirst = A.Operand.Register (A.Register.make 1)
  val viaSecond = L.Operand.Register (L.Register.make 2)
  val register = L.Operand.Register
end

structure Data =
struct
  structure Register = struct datatype t = T of int * int  fun show (T (a, b)) = "T (" ^ Int.toString a ^ "," ^ Int.toString b ^ ")" end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure Flat =
struct
  structure Register = struct type t = int * int  fun make n = (n, n * 10)  fun show (a, b) = "(" ^ Int.toString a ^ "," ^ Int.toString b ^ ")" end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure Boxed =
struct
  structure Register = struct type t = int  fun make n = n * 100  val show = Int.toString end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure DD = D (struct
                    structure amd64 = Data
                    structure mlton = struct structure amd64 = Data  structure live = struct structure amd64 = Data end end
                  end)
structure BF = B (struct
                    structure amd64 = Flat
                    structure mlton = struct structure amd64 = Flat  structure live = struct structure amd64 = Flat end end
                  end)
structure BB = B (struct
                    structure amd64 = Boxed
                    structure mlton = struct structure amd64 = Boxed  structure live = struct structure amd64 = Boxed end end
                  end)
val () = print (String.concatWith "; " [DD.first DD.viaFirst, DD.first DD.viaSecond, DD.second DD.viaFirst, DD.second DD.viaSecond,
                                        DD.second (DD.register (Data.Register.T (5, 6))), DD.second (Data.Operand.Imm 7)] ^ "\n")
val () = print (String.concatWith "; " [BF.first BF.viaFirst, BF.first BF.viaSecond, BF.second BF.viaFirst, BF.second BF.viaSecond,
                                        BF.second (BF.register (5, 6)), BF.second (Flat.Operand.Imm 7)] ^ "\n")
val () = print (String.concatWith "; " [BB.first BB.viaFirst, BB.first BB.viaSecond, BB.second BB.viaFirst, BB.second BB.viaSecond,
                                        BB.second (BB.register 5), BB.second (Boxed.Operand.Imm 7)] ^ "\n")
