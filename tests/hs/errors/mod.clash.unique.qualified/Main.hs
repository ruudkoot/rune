-- Report 5.5.2: the same of a qualified name.
module Main (main) where

import qualified B as Q
import qualified C as Q

main :: IO ()
main = print Q.y
