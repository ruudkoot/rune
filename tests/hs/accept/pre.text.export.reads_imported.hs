-- rows: pre.text.export.shows pre.text.export.readreadspreccreadlist pre.text.export.showshowspreccshowcshowlist pre.text.export.reads.2 pre.text.export.shows.2 pre.text.export.read pre.text.export.lex pre.text.export.showchar pre.text.export.showstring pre.text.export.readparen pre.text.export.showparen
-- Report 8: module Prelude exports each of these (PreludeText): an explicit import of every one compiles, and each name
-- is used.
module Main (main) where

import Prelude (ReadS, ShowS, Read(readsPrec, readList), Show(showsPrec, show, showList), reads, shows, read, lex, showChar, showString, readParen, showParen, IO, Int, return)

t0 :: ReadS Int -> ()
t0 _ = ()

t1 :: ShowS -> ()
t1 _ = ()

c2 :: (Read a) => a -> ()
c2 _ = ()
s2_0 _ = readsPrec
s2_1 _ = readList

c3 :: (Show a) => a -> ()
c3 _ = ()
s3_0 _ = showsPrec
s3_1 _ = show
s3_2 _ = showList

v4 _ = reads

v5 _ = shows

v6 _ = read

v7 _ = lex

v8 _ = showChar

v9 _ = showString

v10 _ = readParen

v11 _ = showParen

main :: IO ()
main = return ()
