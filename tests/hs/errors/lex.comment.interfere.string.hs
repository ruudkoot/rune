-- Report 2.3: {- or -} in a string inside commented-out code interferes with the nesting: the comment ends at the
-- -} in the string, and what follows is no program.
module Main (main) where

main :: IO ()
main = return ()

{-
x = "-}"
-}
