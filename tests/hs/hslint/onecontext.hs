-- HsLint's second inference: the constraints of a declaration group form one context for each of
-- its variables (Report 4.5.2, R21(a), the text by D32), so Num on a variable that only g's type
-- mentions is ambiguous in f's and is defaulted: g is a -> Integer, not Num b => a -> b.
module Main (main) where

f x = const x (g x)
g y = const 0 (f y)

main :: IO ()
main = print (f 'c', g True)
