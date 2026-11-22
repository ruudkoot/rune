-- Report 4.5.5, Rule 2: the determining use may be anywhere in the module: len1 at Rational by len2 (R20: rhc
-- defaults at the end of the module, D32; the Report's example, with genericLength at Num a => [b] -> a, R48).
module Main (main) where

import Ratio

genericLength :: Num a => [b] -> a
genericLength = foldr (\_ n -> n + 1) 0

len1 = genericLength "Hello"
len2 = (2 * len1) :: Rational

main :: IO ()
main = print len2
