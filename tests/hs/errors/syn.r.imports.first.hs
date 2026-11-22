-- Report 9.5: module -> module modid [exports] where body, body -> { impdecls ; topdecls }: every import comes
-- before every declaration.
module Main (main) where

x :: Int
x = 1

import Char

main :: IO ()
main = return ()
