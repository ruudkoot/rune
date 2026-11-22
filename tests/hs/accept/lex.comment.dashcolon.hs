-- Report 2.2, with erratum Dec 2005: comment -> dashes [any<symbol | :> {any}] newline, so `--:` is a varsym,
-- not the start of a comment: here an operator defined and used.
module Main (main) where

main :: IO ()
main = print (1 --: 2)
  where
    (--:) :: Int -> Int -> Int
    a --: b = a + b
