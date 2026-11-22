-- rows: R49 R156
-- Report 21.2.2, 21.8: a semi-closed handle is neither open nor closed, hIsOpen and hIsClosed both False (readings.md R156,
-- the lead's ruling 37: implementation-defined, as GHC does); after hClose it is closed.
module Main (main) where

import IO

main :: IO ()
main = do
  writeFile "semi-state.txt" "abc"
  h <- openFile "semi-state.txt" ReadMode
  s <- hGetContents h
  o <- hIsOpen h
  c <- hIsClosed h
  print (o, c)
  putStrLn s
  hClose h
  c2 <- hIsClosed h
  print c2
