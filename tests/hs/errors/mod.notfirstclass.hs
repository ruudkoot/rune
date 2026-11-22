-- Report 5: modules are not first-class values: a module's name is no expression.
module Main (main) where

import qualified Char

x = Char

main :: IO ()
main = return ()
