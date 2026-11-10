-- Report 2.2: uniSymbol -> any Unicode symbol or punctuation: U+2200 and U+00A7 form operators.
module Main (main) where

main :: IO ()
main = print (1 ∀ 2, 3 § 4)
  where
    a ∀ b = a + b :: Int
    a § b = a * b :: Int
