-- Report 4.4.3.2: let (x, y) = undefined in x diverges once x is demanded.
module Main (main) where

main :: IO ()
main = print (let (x, y) = undefined in x :: Int)
