-- rows: lib.io.bracket lib.io.bracketu lib.io.iseof lib.io.hready
-- Report 21, 21.11: try, bracket and bracket_ against the Report's own code copied under new names (on success, on a user
-- error and a file error, the order of acquire, use and release, an error inside), and isEOF = hIsEOF stdin and
-- hReady h = hWaitForInput h 0, the synopsis's definitions.
module Main (main) where

import IO

try_r            :: IO a -> IO (Either IOError a)
try_r f        =  catch (do r <- f
                            return (Right r))
                        (return . Left)

bracket_r        :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket_r before after m = do
        x  <- before
        rs <- try_r (m x)
        after x
        case rs of
           Right r -> return r
           Left  e -> ioError e

-- variant of the above where middle computation doesn't want x
bracket__r        :: IO a -> (a -> IO b) -> IO c -> IO c
bracket__r before after m = do
         x  <- before
         rs <- try_r m
         after x
         case rs of
            Right r -> return r
            Left  e -> ioError e

isEOF_r :: IO Bool
isEOF_r = hIsEOF stdin

hReady_r :: Handle -> IO Bool
hReady_r h = hWaitForInput h 0

norm :: Either IOError a -> Either (String, Bool) a
norm = either (\e -> Left (ioeGetErrorString e, isUserError e)) Right

say :: String -> IO ()
say = putStrLn

main :: IO ()
main = do
  a1 <- try (return 'x')
  b1 <- try_r (return 'x')
  print (norm a1 == norm b1, norm a1)
  a2 <- try (ioError (userError "boom") >> return 'y')
  b2 <- try_r (ioError (userError "boom") >> return 'y')
  print (norm a2 == norm b2, norm a2)
  a3 <- try (openFile "no-such-file" ReadMode >> return ())
  b3 <- try_r (openFile "no-such-file" ReadMode >> return ())
  print (either isDoesNotExistError (const False) a3, either isDoesNotExistError (const False) b3)
  bracket (say "acquire" >> return 5) (\x -> say ("release " ++ show x)) (\x -> say "use" >> return (x * 2)) >>= print
  bracket_r (say "acquire" >> return 5) (\x -> say ("release " ++ show x)) (\x -> say "use" >> return (x * 2)) >>= print
  t1 <- try (bracket (say "acquire" >> return 'h') (\_ -> say "release") (\_ -> ioError (userError "inside") >> return ()))
  t2 <- try (bracket_r (say "acquire" >> return 'h') (\_ -> say "release") (\_ -> ioError (userError "inside") >> return ()))
  print (norm t1, norm t2)
  bracket_ (say "before") (\_ -> say "after") (say "middle" >> return 'z') >>= print
  bracket__r (say "before") (\_ -> say "after") (say "middle" >> return 'z') >>= print
  t3 <- try (bracket_ (say "before") (\_ -> say "after") (ioError (userError "mid") >> return 'z'))
  t4 <- try (bracket__r (say "before") (\_ -> say "after") (ioError (userError "mid") >> return 'z'))
  print (norm t3, norm t4)
  e1 <- isEOF
  e2 <- isEOF_r
  print (e1, e2)
  writeFile "ready.txt" "ab"
  h <- openFile "ready.txt" ReadMode
  r1 <- hReady h
  r2 <- hReady_r h
  print (r1, r2)
  hClose h
