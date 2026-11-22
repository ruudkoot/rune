-- Report 2.4: \ and | are reserved, and \\ and || are varsyms all the same, by maximal munch.
module Main (main) where

import Prelude hiding ((||))

(\\), (||) :: Int -> Int -> Int
a \\ b = a - b
a || b = a + b

main :: IO ()
main = print (3 \\ 1, 3 || 1)
