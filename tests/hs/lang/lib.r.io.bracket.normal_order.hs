-- rows: lib.r.io.bracket.underscore lib.r.io.bracket
-- Report 21.11: bracket's result is the computation's, after the release; bracket_ is bracket whose middle computation
-- does not want the acquired value; an IOError inside runs the release and propagates.
module Main (main) where

import IO

main :: IO ()
main = do
  r <- bracket (putStrLn "acquire" >> return 3) (\x -> putStrLn ("release " ++ show x)) (\x -> putStrLn "compute" >> return (x + 1))
  print r
  s <- bracket_ (putStrLn "before") (\_ -> putStrLn "after") (putStrLn "middle" >> return "done")
  putStrLn s
  t <- try (bracket (return ()) (\_ -> putStrLn "release on error") (\_ -> ioError (userError "inside")))
  print (either ioeGetErrorString (const "none") t)
