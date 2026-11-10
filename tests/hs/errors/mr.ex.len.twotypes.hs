-- Report 4.5.5: len is restricted, so has one type.
module Main (main) where

import List (genericLength)

main :: IO ()
main = print (let len = genericLength "ab" in (len :: Int, len :: Double))
