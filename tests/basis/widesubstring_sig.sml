(* requires: WideSubstring WideString WideChar WideCharVectorSlice *)
(* uses: spec-sigs/SUBSTRING.sml *)
(* WideSubstring matches SUBSTRING, `where type substring =
   WideCharVectorSlice.slice where type string = WideString.string where type
   char = WideChar.char`, as Substring matches it with CharVectorSlice.slice. *)
structure TestWideSubstringSig =
struct
  structure S : SPEC_SUBSTRING
    where type substring = WideCharVectorSlice.slice
    where type string = WideString.string
    where type char = WideChar.char = WideSubstring
  val () = T.check ("WideSubstring:SUBSTRING/matches", fn () => true)
  val () = T.check ("WideSubstring:SUBSTRING/substring-is-WideCharVectorSlice.slice",
                    fn () => WideCharVectorSlice.length (S.full (WideString.str (WideChar.chr 97))) = 1)
  val () = T.check ("WideSubstring:SUBSTRING/string-is-WideString.string",
                    fn () => WideString.size (S.string (S.full (WideString.str (WideChar.chr 97))) : WideString.string) = 1)
  val () = T.check ("WideSubstring:SUBSTRING/char-is-WideChar.char",
                    fn () => WideChar.ord (S.sub (S.full (WideString.str (WideChar.chr 97)), 0)) = 97)
end
