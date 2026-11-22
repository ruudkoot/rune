-- Report 5.3.3: under an as clause the entities are named by the alias, not the module's name.
module Main (main) where

import qualified A as C

main :: IO ()
main = print A.x
