-- Report 6.3.1: an Eq instance defining neither method loops in both: bottom. On the VM the loop is a stack
-- overflow, status 2, at the 16 MB its .vmargs give (the default 1 GB took 14 to 86 s and up to 9.7 GB); on Core's
-- interpreter, a bottom past its depth (109 s, 6.7 GB), so the program is nightly (tests/hs/lang-nightly.txt).
module Main (main) where

data A = A
instance Eq A

main :: IO ()
main = do
  putStrLn "probe"
  print (A == A)
