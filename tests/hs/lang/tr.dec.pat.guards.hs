-- Report 4.4.3.2: a pattern binding p | g1 = e1 ... | gm = em where decls is p = let decls in if g1 then e1 else ...
-- else error "Unmatched pattern": its guards see the where's bindings and are tried in order, and the binding is
-- lazy, so an unmatched one is an error only where it is forced. Differenced against the compiled form by
-- hs/interp-vm, and against decision trees by hs/desugar/orders.
module Main (main) where

a, b :: Int
(a, b) | c > 5 = (c, 1)
       | c > 2 = (c, 2)
       | otherwise = (0, 3)
  where c = 4

z :: Int
z | False = 1

main :: IO ()
main = do
  print (a, b)
  print (fst (1 :: Int, z))
  print z
