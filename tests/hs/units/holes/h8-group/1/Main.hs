module Main where

import B

main :: IO ()
main = print (case b of { E -> 1; M _ -> 2 })
