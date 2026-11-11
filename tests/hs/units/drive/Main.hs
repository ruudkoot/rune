-- A module of hs/units/drive: it imports Lib whole.
module Main (main) where

import Lib

main :: IO ()
main = putStrLn greeting >> print (double 21)
