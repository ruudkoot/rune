module Main where

import M (C(..), T(..))

k :: String
k = "!"

main :: IO ()
main = putStrLn (m T ++ k)
