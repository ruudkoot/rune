-- Report 4.1.3: an assertion's type is no list: not Eq [a].
module Main (main) where

f :: Eq [a] => a -> a
f x = x

main :: IO ()
main = return ()
