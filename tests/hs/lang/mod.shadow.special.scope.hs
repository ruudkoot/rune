-- Report 5.6.2, 3 (readings.md R22): comprehensions, do, literals and [1..] work with none of their names in scope.
module Main (main) where

import Prelude ()
import qualified Prelude as P

main :: P.IO ()
main = do
  n <- P.return [x | x <- [1 .. 3 :: P.Int]]
  P.print n
  P.print (take2 [1 ..])
  where take2 :: [P.Integer] -> [P.Integer]
        take2 xs = P.take 2 xs
