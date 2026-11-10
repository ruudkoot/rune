-- rows: tr.dec.strict.lambda tr.dec.fun tr.dec.pat.guards
-- rows: R86
-- Report 3.17.3, readings.md R86: the obligation is -O0's literal rules against decision trees over the corpus and generated
-- programs, which waits for rhc compiling them; this program runs now, the overlapping patterns its first sample.
module Main (main) where

f :: (Maybe Int, [Bool]) -> Int
f (Just 0, _) = 1
f (_, [True]) = 2
f (Just n, b : _) | b = n
f (Nothing, []) = 4
f _ = 5

main :: IO ()
main = print (map f [(Just 0, []), (Nothing, [True]), (Just 7, [True, False]), (Nothing, []), (Just 3, [False])])
