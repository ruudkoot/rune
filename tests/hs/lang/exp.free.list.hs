-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: list syntax is the Prelude's lists, under any imports: here only IO, Int and print.
module Main (main) where

import Prelude (IO, Int, print)

xs :: [Int]
xs = [1, 2]

main :: IO ()
main = print xs
