structure IntegerNeed = BenchIntegerFn (BenchNeed)
structure IntegerStrict = BenchIntegerFn (BenchStrict)
structure IntegerTests =
struct
  structure M = BenchSigned64
  fun read path = let val input = TextIO.openIn path val data = TextIO.inputAll input
                  in TextIO.closeIn input; data end
  val operations = ["add", "sub", "mul", "div", "mod", "quot", "rem", "gcd", "lcm", "eq", "lt", "le", "gt", "ge"]
  fun word s = Word64.fromLargeInt (valOf (IntInf.fromString s))
  fun operation name =
    let fun find ([], []) = raise Fail "unknown reference operation"
          | find (n :: names, f :: rest) = if n = name then f else find (names, rest)
          | find _ = raise Fail "reference operation mismatch"
    in find (operations, IntegerNeed.machine) end
  val _ = List.app (fn text => case String.tokens Char.isSpace text of
      [a, b, name, expected] => T.check ("integer/" ^ name ^ "/" ^ a ^ "/" ^ b, fn () =>
        Word64.toString (operation name (word a, word b)) = expected)
    | _ => raise Fail "invalid arithmetic fixture")
    (String.tokens (fn c => c = #"\n") (read "arithmetic.expected"))
  val _ = T.check ("integer/signed64-add-wrap", fn () => Word64.toString (Word64.+ (0wx7fffffffffffffff, 0w1)) = "8000000000000000")
  val _ = T.check ("integer/signed64-sub-wrap", fn () => Word64.toString (Word64.- (0wx8000000000000000, 0w1)) = "7FFFFFFFFFFFFFFF")
  val _ = T.check ("integer/signed64-multiply-wrap", fn () => Word64.toString (Word64.* (0wx7fffffffffffffff, 0w2)) = "FFFFFFFFFFFFFFFE")
  val _ = T.check ("integer/division-zero", fn () => ((ignore (M.divide (0w7, 0w0)); false) handle Div => true))
  val _ = T.check ("integer/quotient-overflow", fn () => ((ignore (M.quotient (0wx8000000000000000, 0wxffffffffffffffff)); false) handle Overflow => true))
  val _ = T.check ("integer/gcd-zero", fn () => M.gcd (0w0, 0w0) = 0w0)
  val _ = T.check ("integer/lcm-zero", fn () => M.lcm (0w0, 0w0) = 0w0 andalso M.lcm (0w9, 0w0) = 0w0)
  val lazyResult = IntegerNeed.run (~2100000000, 700000001, 2100000000)
  val strictResult = IntegerStrict.run (~2100000000, 700000001, 2100000000)
  fun validates values path = (IntegerCheck.validate values path; true)
  val _ = T.check ("integer/complete-lazy-smoke", fn () => validates lazyResult "smoke.expected")
  val _ = T.check ("integer/complete-strict-smoke", fn () => validates strictResult "smoke.expected")
  val _ = T.check ("integer/lazy-strict-agree", fn () => lazyResult = strictResult)
  fun rejects path = (IntegerCheck.validate lazyResult path; false) handle Fail _ => true
  val _ = T.check ("integer/wrong-count-rejected", fn () => rejects "wrong-count.expected")
  val _ = T.check ("integer/wrong-digest-rejected", fn () => rejects "wrong-digest.expected")
  val _ = T.check ("integer/truncated-rejected", fn () => rejects "truncated.expected")
  val _ = T.check ("integer/extra-rejected", fn () => rejects "extra.expected")
  val _ = T.check ("integer/memoized-lazy-tail-demand", fn () =>
    let val calls = ref 0
        val xs = IntegerNeed.enum (fn (a, b) => (calls := !calls + 1; a + b)) (op <=) (1, 1, 3)
        val _ = IntegerNeed.S.head xs
        val beforeTail = !calls
        val tail = IntegerNeed.S.tail xs
        val _ = IntegerNeed.S.head tail
        val afterTail = !calls
        val _ = IntegerNeed.S.head (IntegerNeed.S.tail xs)
    in beforeTail = 0 andalso afterTail = 1 andalso !calls = 1 end)
  val _ = T.check ("integer/strict-enumeration-eager", fn () =>
    let val calls = ref 0
        val xs = IntegerStrict.enum (fn (a, b) => (calls := !calls + 1; a + b)) (op <=) (1, 1, 3)
    in !calls = 3 andalso IntegerStrict.S.head xs = 1 end)
end
