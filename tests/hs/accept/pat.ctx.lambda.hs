-- rows: pat.ctx.function pat.ctx.binding pat.ctx.comp pat.ctx.do pat.ctx.case pat.npk.toplevel pat.npk.nested pat.neg.int pat.neg.float pat.lit.int pat.lit.float pat.lit.char pat.lit.string pat.con.arity.nullary pat.as.form pat.tuple.form pat.list.form pat.paren.form pat.irref.form pat.label.form pat.label.npk pat.guard.toplevel
-- Report 3.17 and 3.17.1: patterns in lambdas, functions, bindings, comprehensions, do and case; n+k at the top and in
-- parentheses; negative and other literals; constructors of no arity; as, tuple, list, parenthesised, lazy and
-- labelled patterns, qualified, empty and with an n+k field; guards on case, function and pattern bindings.
module Main (main) where

import qualified Prelude as P
import Prelude

data R = R { f :: Int } | Q deriving Show

h :: Int -> Double -> Char -> String -> Maybe Int -> [Int] -> Int
h 0 _ _ _ _ _ = 1
h (-1) _ _ _ _ _ = 2
h _ (-1.5) _ _ _ _ = 3
h _ 1.5 _ _ _ _ = 4
h _ _ 'a' _ _ _ = 5
h _ _ _ "ab" Nothing _ = 6
h (n+1) _ _ _ (Just (m+1)) xs@(x:_) | n > 0 = n + m + x
h _ _ _ _ _ _ = 0

k :: (Int, Int, Int) -> [Int] -> ((Int)) -> R -> Int
k (x, y, z) [a] ((b)) ~(R { f = c }) = x + y + z + a + b + c
k _ [a, b] _ Main.R { Main.f = n+1 } = a + b + n
k _ _ _ R {} = 0
k _ _ _ Q = 0

(p, q) | True = (1 :: Int, 2 :: Int)

main :: IO ()
main = do
  (u, v) <- return (1, 2)
  print ((\(x, y) -> x + y) (u, v), [ x | (x, _) <- [(1, 2)] ], case (1, 2) of (x, _) -> x, p + q)
  print (h 1 0 'b' "" Nothing [], k (1, 2, 3) [4] 5 (R 6), case 3 :: Int of { n+1 -> n ; _ -> 0 })
