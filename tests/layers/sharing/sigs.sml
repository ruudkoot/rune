(* MLton's amd64 codegen in small (amd64-allocate-registers.sig and the
   signatures it names): ARGS shares a structure, amd64, with a view of it,
   mlton.amd64, that has Operand but not Register. So Operand.t is one
   name that two specifications of the datatype give, amd64's and
   mlton.live.amd64's, and Register.t is two names, which no equation
   identifies: the constructor Register of one specification takes
   amd64.Register.t, of the other mlton.live.amd64.Register.t. A
   functor's parameter enters one list of constructors for the name, which
   its unit's static layer writes; the compile and the analysis must
   enter the same (Elaborate.specDatatypes). Register.t is a datatype, as
   MLton's is: an abstract one would make Register an open constructor
   that each specification gives at its own type *)
signature PARTIAL = sig structure Operand : sig type t end end
signature FULL =
sig
  structure Register : sig datatype t = T of int end
  structure Operand : sig datatype t = Register of Register.t | Imm of int end
end
signature LIVE = sig structure amd64 : FULL end
signature MLT = sig structure amd64 : PARTIAL  structure live : LIVE  sharing amd64 = live.amd64 end
signature ARGS = sig structure amd64 : FULL  structure mlton : MLT  sharing amd64 = mlton.amd64 end
