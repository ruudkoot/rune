-- Report 4.4.1: without its signature the Report's f is T Int -> Int, so not at T Bool.
module Main (main) where

data T a = K (T Int) (T a)

f (K x y) = if f x == 1 then f y else undefined

use :: T Bool -> Bool
use = f

main :: IO ()
main = return ()
