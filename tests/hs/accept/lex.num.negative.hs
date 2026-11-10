-- Report 2.5: "Negative numeric literals are discussed in Section 3.4": no literal lexes with a sign, so `-1` is the
-- prefix minus and the literal, as `- 1` is.
module Main (main) where

main :: IO ()
main = print ((-1) == (- 1 :: Int), 3 -1 :: Int)
