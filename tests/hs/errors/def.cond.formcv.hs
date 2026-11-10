-- Report 4.3.4: a variable defaults only where its constraints are all of the form C v: Eq (m v) stops it.
module Main (main) where

f :: (Eq (m v), Num v, Monad m) => m v -> Bool
f x = x == return 1

main :: IO ()
main = print (f undefined)
