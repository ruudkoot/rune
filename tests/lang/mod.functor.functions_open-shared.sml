(* --functors=functions: a parameter's open constructor of a datatype two
   specifications give. Sharing a structure with a view of it that has Operand
   but not Register (MLton's amd64-allocate-registers.sig) makes Operand.t one
   name whose Register takes amd64.Register.t in one specification and
   mlton.live.amd64.Register.t in the other, two abstract types. Its descriptor
   and its functions are the first specification's, as the code's tables are:
   laid out flat by one argument and boxed by another, taken apart and built
   in the body *)
signature PARTIAL = sig structure Operand : sig type t end end
signature FULL =
sig
  structure Register : sig type t  val show : t -> string end
  structure Operand : sig datatype t = Register of Register.t | Imm of int end
end
signature LIVE = sig structure amd64 : FULL end
signature MLT = sig structure amd64 : PARTIAL  structure live : LIVE  sharing amd64 = live.amd64 end
signature ARGS = sig structure amd64 : FULL  structure mlton : MLT  sharing amd64 = mlton.amd64 end
functor Allocate (S : ARGS) =
struct
  fun look (S.amd64.Operand.Register r) = "Register " ^ S.amd64.Register.show r
    | look (S.amd64.Operand.Imm n) = "Imm " ^ Int.toString n
  fun again v = case v of S.amd64.Operand.Register r => S.amd64.Operand.Register r | other => other
end
structure Flat =
struct
  structure Register = struct type t = int * int  fun show (a, b) = "(" ^ Int.toString a ^ "," ^ Int.toString b ^ ")" end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure Boxed =
struct
  structure Register = struct type t = int  val show = Int.toString end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure F = Allocate (struct
                          structure amd64 = Flat
                          structure mlton = struct structure amd64 = Flat  structure live = struct structure amd64 = Flat end end
                        end)
structure B = Allocate (struct
                          structure amd64 = Boxed
                          structure mlton = struct structure amd64 = Boxed  structure live = struct structure amd64 = Boxed end end
                        end)
val () = print (F.look (Flat.Operand.Register (3, 4)) ^ "; " ^ F.look (F.again (Flat.Operand.Register (5, 6))) ^ "; "
                ^ F.look (Flat.Operand.Imm 7) ^ "\n")
val () = print (B.look (Boxed.Operand.Register 3) ^ "; " ^ B.look (B.again (Boxed.Operand.Register 5)) ^ "; "
                ^ B.look (Boxed.Operand.Imm 7) ^ "\n")
