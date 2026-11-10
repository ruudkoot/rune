-- Report 21.10.2: the Report's shorter example by string I/O, its main run on the program's arguments.
module Main (main) where

import System
import Char( toUpper )

main = do
         writeFile "upper-in.txt" "Hello, World\nsecond line\n"
         reportMain
         readFile "upper-out.txt" >>= putStr

reportMain = do
         [f1,f2] <- getArgs
         s <- readFile f1
         writeFile f2 (map toUpper s)
