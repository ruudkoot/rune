-- D17's C for a generalised binding (rhc --selectors=generalised; hs/selectors/generalised): a local pattern
-- binding the checker generalised, (us, vs), used at two types, is one tuple at every type and its variables that
-- tuple's selectors, marked, under the option; and without it, each variable a lazy match of its own (rule (d)),
-- the bytecode the same as with --selectors=monomorphic, the default. Both print the same.
module Main (main) where

main :: IO ()
main = do
  let (us, vs) = splitAt 4000 (replicate 7000 [])
  print (length (us :: [[Int]]), length (vs :: [String]))
