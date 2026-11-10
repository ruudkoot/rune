-- rows: exp.tuple.lazy
-- Report 3.8: (a,b,c) and (,,) a b c are the same value, (,,) may be partially applied, and forming a tuple evaluates no
-- component.
module Main (main) where

main :: IO ()
main = do
  print ((1, 'a', True) == (,,) 1 'a' True)
  print (map ((,,) 1 'b') [True])
  print (fst (1, undefined :: Int))
