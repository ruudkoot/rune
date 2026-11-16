-- Report 7.1: writeFile writes the string to the file. rhc's policy is that
-- this costs per character little more than walking the string: the
-- runtime's loop (rtPutChars) writes each character as it is evaluated, so
-- that what comes before a bottom is written, with no IO action of the
-- library's for each. io.writefile.budget: writing n characters costs at most
-- 1.0 times counting them (0.74 measured); through the library's loop of an IO action a
-- character, as before 2026-11-16, it was 2.19 times.
module Main (main) where

main :: IO ()
main = do
  [m, n] <- fmap (map read . words) getLine
  let s = concat (replicate (n `div` 80) (replicate 79 'x' ++ "\n"))
  if m == 1 then writeFile "out.txt" s else print (length s)
