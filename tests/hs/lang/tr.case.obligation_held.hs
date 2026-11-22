-- rows: tr.dec.fun R86
-- Report 3.17.3, readings.md R86: the obligation is the literal rules against decision trees, which hs/desugar/orders
-- holds on every program of tests/hs/lang (this one, with overlapping patterns and a guard, among them) and
-- hs/generated/@orders on generated programs; and the literal translation against the compiled form, hs/interp-vm.
module Main (main) where

f :: (Maybe Int, [Bool]) -> Int
f (Just 0, _) = 1
f (_, [True]) = 2
f (Just n, b : _) | b = n
f (Nothing, []) = 4
f _ = 5

main :: IO ()
main = print (map f [(Just 0, []), (Nothing, [True]), (Just 7, [True, False]), (Nothing, []), (Just 3, [False])])
