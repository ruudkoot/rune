(* SysWord: the words of the operating system's interfaces, `Posix`'s and
   `Windows`'s: their flags, modes and numbers. "The type SysWord.word is
   guaranteed to be large enough to hold any unsigned integral value used by
   the underlying system", which on a 64-bit system has 64 bits, so it is
   `Word64` behind, but a type of its own: not `Word.word`, nor
   `Word64.word`, as the specification makes it the same as neither, and
   other implementations keep it apart from each (MLton's is `Word64`, and
   its `word` has 32 bits). A program converts with `fromLarge`, `toLarge`,
   `fromInt` and `toInt`.

   Implements: WORD

   Status: optional *)
structure SysWord :> WORD = Word64

(* Word constants at SysWord.word, converted from their digits where they
   are evaluated; one past the 64 bits raises Overflow. *)
structure RuneSysWord =
struct
  (* between the words of the VM, in which the library's flags are kept,
     and SysWord's: toWord keeps the low bits *)
  fun fromWord (w : Word.word) : SysWord.word = SysWord.fromLarge (Word.toLarge w)
  fun toWord (w : SysWord.word) : Word.word = Word.fromLarge (SysWord.toLarge w)
  fun fromLit (digits : string) : SysWord.word =
    case IntInf.fromString digits of
      SOME i => if IntInf.> (i, SysWord.toLargeInt (SysWord.notb (SysWord.fromInt 0))) then raise Overflow
                else SysWord.fromLargeInt i
    | NONE => raise Fail "RuneSysWord.fromLit"
end

_overload word SysWord via RuneSysWord.fromLit
