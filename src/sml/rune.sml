(* Public compiler entry point: parse, type-check, then emit bytecode. *)
signature RUNE_COMPILER =
sig
  val compile : string -> Word8Vector.vector
  val compileEmpty : unit -> Word8Vector.vector
end

structure RuneCompiler : RUNE_COMPILER =
struct
  fun compile source =
    let
      val expression = RuneParser.parse source
      val _ = RuneTycheck.check expression
    in
      RuneEmit.emit expression
    end

  fun compileEmpty () = compile "0"
end
