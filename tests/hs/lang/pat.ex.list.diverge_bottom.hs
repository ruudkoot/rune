-- Report 3.17.2: ['a','b'] against [bottom,'x']: 'a' against bottom diverges.
module Main (main) where

l :: String -> Int
l ['a', 'b'] = 1
l _ = 2

main :: IO ()
main = print (l [undefined, 'x'])
