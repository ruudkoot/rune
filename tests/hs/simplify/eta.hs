-- Eta under the pedantic rule (D48's C): a function whose lambda is behind
-- a case keeps its arity, so `seq` of it applied to bottom is bottom (6.2).
-- GHC's default (D's, --eta=ghc) eta-expands through the case, and this
-- prints "converged" where it must not (eta.ghc.expected): the pedantic
-- rule is rhc's default, which hs/simplify/eta/eta holds it to.
module Main where

-- f is recursive, so that no pass inlines it and seq sees f itself
f :: Bool -> Int -> Int
f b = case b of
        True -> \y -> y + 1
        False -> \y -> if y > 100 then f True y else y - 1

main :: IO ()
main = do
  print (map (f True) [1, 2, 3], map (f False) [1, 2, 3])
  (f undefined) `seq` putStrLn "converged"
