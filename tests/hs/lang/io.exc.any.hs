-- rows: io.exc.allcaught io.exc.catch.none io.exc.recent io.exc.reraise io.exc.afteraction io.exc.handlerraises io.exc.usererror io.exc.ioerror io.exc.fail
-- Report 7.3: an I/O operation may raise an IOError; catch sees every one, by the most recent handler, covering the
-- action alone; a handler re-raises by ioError, and what it raises goes outward; userError, ioeGetErrorString,
-- and fail s = ioError (userError s).
module Main (main) where

import IO

main :: IO ()
main = do
  r <- catch (readFile "no-such-file" >>= \s -> return (length s)) (\e -> return (-1))
  print r
  r1 <- catch (return 1) (\e -> return (2 :: Int))
  print r1
  catch (catch (ioError (userError "in")) (\e -> putStrLn ("inner " ++ ioeGetErrorString e))) (\e -> putStrLn "outer")
  catch (catch (ioError (userError "x")) (\e -> if isEOFError e then putStrLn "eof" else ioError e)) (\e -> putStrLn ("outer got " ++ ioeGetErrorString e))
  catch (catch (return ()) (\e -> putStrLn "inner") >> ioError (userError "after")) (\e -> putStrLn ("outer: " ++ ioeGetErrorString e))
  catch (catch (ioError (userError "a")) (\e -> ioError (userError "b"))) (\e -> putStrLn ("from handler: " ++ ioeGetErrorString e))
  catch (fail "boom") (\e -> putStrLn (show (isUserError e) ++ " " ++ ioeGetErrorString e))
