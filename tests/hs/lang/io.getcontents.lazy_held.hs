-- rows: pre.r.interact.buffering R83
-- Report 7.1, readings.md R83: getContents is lazy; this runs now, and waits for a runner that feeds standard input in steps
-- and checks the output between them, which is what shows the laziness.
module Main (main) where

main :: IO ()
main = do
  s <- getContents
  putStrLn "prompt"
  mapM_ putStrLn (take 2 (lines s))
