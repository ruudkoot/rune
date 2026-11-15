-- Report 22: removeFile of a directory fails. Uncaught, the IOError ends the program (7.3). The directory it made is
-- removed before the error goes on uncaught, so that a run leaves nothing for the next in the same place (hs/jit
-- runs it in each way in one directory, and counts its work).
module Main (main) where

import Directory

main :: IO ()
main = do
  createDirectory "d"
  removeFile "d" `catch` (\e -> removeDirectory "d" >> ioError e)
