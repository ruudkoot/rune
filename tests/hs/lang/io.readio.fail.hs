-- Report 7.1: readIO signals a parse failure to the I/O monad, as a userError (chapter 8), instead of ending the program.
module Main (main) where

import IO

main :: IO ()
main = do
  r <- catch (readIO "x" >>= \n -> return (show (n :: Int))) (\e -> return (if isUserError e then "user" else "other"))
  putStrLn r
