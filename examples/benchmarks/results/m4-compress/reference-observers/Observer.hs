module Main where
import Encode
import BinConv
import PTTrees
import System.IO
import System.Environment
import Control.Monad
import Control.Exception
import Text.Printf
main = do
  [path,output] <- getArgs
  withBinaryFile path ReadMode $ \file -> do
    input <- hGetContents file
    let len = length input
    evaluate len
    forM_ [0..30] $ \cut -> do
      let bytes = map toEnum (codes_to_ascii (encode (take (len-cut) input)))
      withBinaryFile (output ++ "/cut-" ++ printf "%02d" (cut::Int) ++ ".bin") WriteMode $ \out -> hPutStr out bytes
  case initial_table of
    PT (PTE key value _) _ _ -> putStrLn (show (fromEnum key,value))
    _ -> error "initial table empty"
