-- Report 21.6: a handle with BlockBuffering (Just 4) holds four characters and writes them out whenever another comes
-- (the buffer overflows), and at hFlush and hClose; rhc writes no more often (the lead's ruling 64). `look` shows
-- what the file holds as the system has it (cat), between bars. The points avoid a multiple of four, where writing
-- out on overflow and writing out when full part. GHC writes more often (oracles.txt), which 21.6 allows.
-- interp: no: Core's interpreter writes a file at once, with no buffer, so the buffering shown is the VM's runtime's
module Main (main) where

import IO
import System

look :: String -> IO ()
look tag = do
  putStr (tag ++ ": |")
  hFlush stdout
  _ <- system "cat b.txt"
  putStrLn "|"

main :: IO ()
main = do
  h <- openFile "b.txt" WriteMode
  hSetBuffering h (BlockBuffering (Just 4))
  hPutStr h "abc"
  look "three"
  hPutStr h "defghij"
  look "ten"
  hFlush h
  look "after hFlush"
  hPutStr h "klmnop"
  look "sixteen"
  hPutChar h 'q'
  look "seventeen"
  mapM_ (hPutChar h) "rstuv"
  look "twenty-two"
  hClose h
  look "after hClose"
