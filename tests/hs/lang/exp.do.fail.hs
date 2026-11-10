-- rows: exp.do.fail.msg exp.do.fail.irref tr.do.let tr.do.ok.fresh
-- Report 3.14: a failed match of p <- e calls fail: Nothing at Maybe, [] at lists, an IOError at IO, with a message;
-- ~p never fails; do {let ds; ss} is let ds in do {ss}; a variable named ok is the program's own.
module Main (main) where

main :: IO ()
main = do
  print (do { Just x <- Just Nothing; return (x :: Int) })
  print (do { Just x <- [Nothing, Just 1]; return (x :: Int) })
  catch (do { Just x <- return Nothing; print (x :: Int) }) (\e -> putStrLn (if null (show e) then "empty" else "caught"))
  print (do { ~(Just x) <- return Nothing; return (1 :: Int) } :: Maybe Int)
  print (do { let { y = 2 }; return (y + 1) } :: Maybe Int)
  print (do { ok <- Just 1; return (ok + 1) } :: Maybe Int)
