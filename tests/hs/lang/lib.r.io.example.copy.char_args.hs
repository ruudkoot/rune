-- Report 21.10.2: the Report's example copying a file to upper case character by character, its main run on the
-- program's arguments after the input file is written.
module Main (main) where

import IO
import System
import Char( toUpper )

main = do
         writeFile "upper-in.txt" "Hello, World\nsecond line\n"
         reportMain
         readFile "upper-out.txt" >>= putStr

reportMain = do
         [f1,f2] <- getArgs
         h1 <- openFile f1 ReadMode
         h2 <- openFile f2 WriteMode
         copyFile h1 h2
         hClose h1
         hClose h2

copyFile h1 h2 = do
                   eof <- hIsEOF h1
                   if eof then return () else
                      do
                        c <- hGetChar h1
                        hPutChar h2 (toUpper c)
                        copyFile h1 h2
