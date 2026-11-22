-- rows: std.io.functor std.ioerror.show std.ioerror.eq R47
-- Report 6.1.7: IO is a Monad and a Functor; IOError is in Eq and Show (what its text and equality are, unspecified).
module Main (main) where

main :: IO ()
main = do
  l <- fmap length getLine
  print l
  x <- do { return (1 :: Int) }
  print (x + 1)
  print (not (null (show (userError "x"))))
  print (seq (userError "x" == userError "x") ())
