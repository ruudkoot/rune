-- rows: mod.imp.ring.default
-- Report 5.3.4's example: in Ring, + and * are its own and Prelude.+ the Prelude's, and succ = (Prelude.+ 1)
-- is defaulted to Integer though Integer is not in scope by name.
module Main (main) where

import qualified Prelude
import Prelude (IO, Int, print, ($))
import Ring

main :: IO ()
main = print $ ([1 :: Int, 2] + [2, 3], [1 :: Int, 2] * [2, 3], succ 5, 1 Prelude.+ (2 :: Int))
