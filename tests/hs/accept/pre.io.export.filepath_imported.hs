-- rows: pre.io.export.ioerror pre.io.export.ioerror.2 pre.io.export.usererror pre.io.export.catch pre.io.export.putchar pre.io.export.putstr pre.io.export.putstrln pre.io.export.print pre.io.export.getchar pre.io.export.getline pre.io.export.getcontents pre.io.export.interact pre.io.export.readfile pre.io.export.writefile pre.io.export.appendfile pre.io.export.readio pre.io.export.readln
-- Report 8: module Prelude exports each of these (PreludeIO): an explicit import of every one compiles, and each name
-- is used.
module Main (main) where

import Prelude (FilePath, IOError, ioError, userError, catch, putChar, putStr, putStrLn, print, getChar, getLine, getContents, interact, readFile, writeFile, appendFile, readIO, readLn, IO, Int, return)

t0 :: FilePath -> ()
t0 _ = ()

t1 :: IOError -> ()
t1 _ = ()

v2 _ = ioError

v3 _ = userError

v4 _ = catch

v5 _ = putChar

v6 _ = putStr

v7 _ = putStrLn

v8 _ = print

v9 _ = getChar

v10 _ = getLine

v11 _ = getContents

v12 _ = interact

v13 _ = readFile

v14 _ = writeFile

v15 _ = appendFile

v16 _ = readIO

v17 _ = readLn

main :: IO ()
main = return ()
