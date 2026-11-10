-- rows: lex.float.decimalonly
-- Report 2.5: "A floating literal must contain digits both before and after the decimal point", and is decimal: `1.`
-- is `1` then `.`, `.5` is `.` then `5`, and `0x1.8` is `0x1`, `.`, `8`, each `.` the operator defined here.
module Main (main) where

main :: IO ()
main = print ((1.) 2, (.5) 3, 0x1.8)
  where
    (.) :: Int -> Int -> Int
    a . b = a + b
