module Main where

import A
import B

main :: IO ()
main = print t >> putStrLn (describe 'a' 'b')
