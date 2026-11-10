-- Report 17.2, 17.9: (\\) is non-associative, infix 5 \\: a \\ b \\ c is refused.
module Main (main) where

import List

x :: [Int]
x = [1, 2, 3] \\ [1] \\ [2]

main :: IO ()
main = print x
