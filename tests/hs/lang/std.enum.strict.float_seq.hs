-- rows: R39
-- Report 6.3.4 and the erratum of May 2003 (readings.md R39): the enumFrom family at Float and Double is strict, so
-- [undefined ..] is bottom as soon as its spine is.
module Main (main) where

main :: IO ()
main = do
  putStrLn "probe"
  print (length (take 2 ([undefined ..] :: [Double])))
