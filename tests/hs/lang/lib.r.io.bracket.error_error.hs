-- rows: R36
-- Report 21.11, R36: bracket is built on try, so only an IOError reaches the release: error inside it skips the release and
-- ends the program.
module Main (main) where

import IO

main :: IO ()
main = do
  bracket (putStrLn "acquire") (\_ -> putStrLn "release") (\_ -> error "not an IOError" :: IO ())
  putStrLn "not reached"
