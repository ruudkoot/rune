-- Report 16.2: as with array, an index repeated in the list of (//) leaves that element bottom.
module Main (main) where

import Array

main :: IO ()
main = do
  putStrLn "before"
  print ((listArray (1, 2) "ab" // [(2, 'x'), (2, 'y')]) ! 2)
