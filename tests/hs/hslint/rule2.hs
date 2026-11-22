-- HsLint's second inference: Rule 2 defaults a monomorphic variable when the module is inferred,
-- so a later use fixes it (Report 4.5.5, R20): the Report's len1 at Rational, with a genericLength
-- of 4.5.5's type (R48), and E7's n = 60 used at Int.
module Main (main) where

genericLength' :: Num a => [b] -> a
genericLength' [] = 0
genericLength' (_ : xs) = 1 + genericLength' xs

len1 = genericLength' "Hello"
len2 = (2 * len1) :: Rational

n = 60
a :: Int
a = n + 1

main :: IO ()
main = print (len2, a)
