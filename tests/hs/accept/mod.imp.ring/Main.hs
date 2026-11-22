-- Report 5.3.2: the Report's Ring: a local entity shares a name with a qualified import.
module Main (main) where

import qualified Prelude
import Prelude (IO, Int, print, ($))
import Ring

main :: IO ()
main = print $ [1 :: Int] + [2]
