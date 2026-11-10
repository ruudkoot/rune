-- Report 3.17.1, 4.4.3: f -1 = 3 binds the operator -, by funlhs's var op pat, not a clause of f.
module Main (main) where

import Prelude hiding ((-))

f -1 = 3

main :: IO ()
main = print (10 - 1 :: Int, 'x' - 1 :: Int)
