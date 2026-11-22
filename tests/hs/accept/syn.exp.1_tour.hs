-- rows: syn.exp.2 syn.expi.1 syn.expi.2 syn.expi.3 syn.lexpi.1 syn.lexp6.1 syn.rexpi.1 syn.exp10.1 syn.exp10.2 syn.exp10.3 syn.exp10.4 syn.exp10.5 syn.exp10.6 syn.fexp.1 syn.aexp.1 syn.aexp.2 syn.aexp.3 syn.aexp.4 syn.aexp.5 syn.aexp.6 syn.aexp.7 syn.aexp.8 syn.aexp.13 syn.aexp.14 syn.qual.1 syn.qual.2 syn.qual.3 syn.alts.1 syn.alt.1 syn.alt.2 syn.alt.3 syn.gdpat.1 syn.stmts.1 syn.stmt.1 syn.stmt.2 syn.stmt.3 syn.stmt.4 syn.fbind.1 syn.decls.1 syn.rhs.1 syn.rhs.2 syn.gdrhs.1 syn.gd.1 syn.r.exp.sigprec syn.r.neg.prec syn.r.neg.lowerop syn.r.exp10.opoperand syn.r.update.notqcon syn.r.construct.empty syn.r.list.nonempty syn.r.stmts.emptystmt syn.r.decls.empty syn.r.tuple.k
-- Report 9.5: exp and the expressions it holds in each form: a signature with a context, operators of each
-- associativity, prefix minus, the forms of exp10 and of aexp, qualifiers, alternatives, statements and field
-- bindings; and right-hand sides with guards and where.
module Main (main) where

data R = R { a :: Int, b :: Int } deriving Show

infix 4 ===
(===) :: Int -> Int -> Bool
x === y = x == y

sign :: Int -> Int
sign n
  | n > 0 = 1
  | n < 0 = -1
  | otherwise = 0
  where {}

main :: IO ()
main = do
  let { r = R { a = 1, b = 2 } ; s = r { a = 3 } { b = 4 } }
  print (s, R {} `seq` (), (- 1))
  x <- return (1 :: Int)
  ;
  print [ y * 2 | y <- [1 .. 3], let z = y, odd z, Just w <- [Just y] ]
  print ([1 ..] !! 2 :: Int, [1, 3 ..] !! 2 :: Int, [1 .. 5 :: Int], [1, 3 .. 9 :: Int], [] :: [Int])
  print (if x === 1 then "one" else "other", case x of { 1 | x > 0 -> "pos" where {} ; _ -> "no" ; })
  print ((\p q -> p + q) 1 2 :: Int, let f n = n * 2 in f x, - x * 2, - x + 1)
  print (x == - 1, sign x, (1 :: Num a => a) + x, (x, x), [x])
  print ((x), (,) x x, (:) x [], (), let {} in x)
  print (x + let y = 1 in y, Just x >>= \v -> Just v)
  return ()
