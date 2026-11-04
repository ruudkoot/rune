(* ARGS matched, as MLton matches it: every view the same structure *)
structure A =
struct
  structure Register = struct datatype t = T of int end
  structure Operand = struct datatype t = Register of Register.t | Imm of int end
end
structure R = Allocate (struct
                          structure amd64 = A
                          structure mlton = struct structure amd64 = A  structure live = struct structure amd64 = A end end
                        end)
val () = print (Int.toString (R.registers (A.Operand.Register (A.Register.T 3)) + R.registers (A.Operand.Imm 4)) ^ "\n")
