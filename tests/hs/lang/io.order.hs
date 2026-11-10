-- rows: io.pure io.putchar io.putstr io.putstrln io.print io.seq.instance io.seq.then io.seq.return
-- Report 7, 7.1, 7.2: actions run in order; evaluating an action does not perform it; putChar, putStr, putStrLn and
-- print; >>, >>= and return.
module Main (main) where

main :: IO ()
main = do
  let a = putStr "x"
  a >> a
  seq a (return ())
  putStrLn ""
  putChar 'c'
  putStr "str"
  putStrLn "ln"
  print (1 :: Int, "a")
  return (1 :: Int) >>= print
  putStr "p" >> putStrLn "q"
