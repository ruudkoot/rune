signature RUNE_BYTECODE =
sig
  datatype instruction = Halt
  val encode : instruction -> Word8Vector.vector
end

structure RuneBytecode : RUNE_BYTECODE =
struct
  datatype instruction = Halt

  fun encode Halt = Word8Vector.fromList [0w0]
end

signature RUNE_COMPILER =
sig
  val compileEmpty : unit -> Word8Vector.vector
end

structure RuneCompiler : RUNE_COMPILER =
struct
  fun compileEmpty () = RuneBytecode.encode RuneBytecode.Halt
end
