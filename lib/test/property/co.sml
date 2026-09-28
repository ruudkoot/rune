(* Observers as hashes (docs/plans/quickcheck.md, D4 and D5). *)

(* Implements: CO *)
structure Co :> CO =
struct
  type 'a co = 'a -> Word64.word

  fun mix (h : Word64.word, w : Word64.word) : Word64.word = Random.hash (Word64.+ (Word64.xorb (h, w), 0wx9E3779B97F4A7C15))

  val int : int co = fn i => Word64.fromInt i
  val word : word co = fn w => Word64.fromLarge (Word.toLarge w)
  val word64 : Word64.word co = fn w => w
  val char : char co = fn c => Word64.fromInt (Char.ord c)
  val bool : bool co = fn b => if b then 0w1 else 0w0
  val unit : unit co = fn () => 0w0
  val order : order co = fn LESS => 0w0 | EQUAL => 0w1 | GREATER => 0w2
  val string : string co = Random.hashString
  val real : real co =
    fn x => Word8Vector.foldr (fn (b, w) => Word64.orb (Word64.<< (w, 0w8), Word64.fromLarge (Word8.toLarge b))) 0w0
                              (PackRealLittle.toBytes x)
  fun option (c : 'a co) : 'a option co = fn NONE => 0w0 | SOME x => mix (0w1, c x)
  fun list (c : 'a co) : 'a list co = fn l => List.foldl (fn (x, h) => mix (h, c x)) (Word64.fromInt (List.length l)) l
  fun pair (c : 'a co, d : 'b co) : ('a * 'b) co = fn (x, y) => mix (mix (0w2, c x), d y)
  fun triple (c : 'a co, d : 'b co, e : 'c co) : ('a * 'b * 'c) co = fn (x, y, z) => mix (mix (mix (0w3, c x), d y), e z)
end
