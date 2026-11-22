-- rows: R95
-- Report 23 (ruling 49 makes the row a run, the lead's ruling 58 its test): a program whose value is "otherwise
-- determined to be _|_" ends as exitFailure does, with status 1. rhc determines this one so: x = x + 1 re-enters its
-- own suspension, blackholed while it is evaluated (form C), on the interpreter and the VM alike, after what was
-- written is flushed. Running out of the stack is D18's limit and not this (std.eq.neither_loops, status 2 on the VM).
module Main (main) where

main :: IO ()
main = do
  putStrLn "before"
  let x = x + 1 :: Integer
  print x
