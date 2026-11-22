-- Report 9.3: "the Unicode characters are assumed to be of the same, fixed, width as an ASCII character": each of the
-- wide characters in the literal below counts one column, so y lines up with x and stays in the let.
module Main (main) where

main :: IO ()
main = print (s, t)
  where s = "中文" ; t = let x = 1 :: Int
                           y = 2 in x + y
