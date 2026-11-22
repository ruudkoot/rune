-- rows: pre.io.putstr pre.io.putstrln pre.io.print pre.io.getchar pre.io.getline pre.io.getcontents pre.io.readio pre.io.readln pre.io.ioerror pre.io.usererror pre.io.catch pre.io.inst.showioerror pre.io.inst.eqioerror
-- Report 8.3 (PreludeIO): putStr, putStrLn, print, getLine, readIO and readLn beside the Report's own definitions;
-- getChar, getContents, ioError, userError and catch; IOError in Show and Eq.
module Main (main) where

putStr' :: String -> IO ()
putStr' s = mapM_ putChar s

putStrLn' :: String -> IO ()
putStrLn' s = do { putStr' s; putStr' "\n" }

print' :: (Show a) => a -> IO ()
print' x = putStrLn' (show x)

getLine' :: IO String
getLine' = do { c <- getChar; if c == '\n' then return "" else do { s <- getLine'; return (c : s) } }

readIO' :: (Read a) => String -> IO a
readIO' s = case [x | (x, t) <- reads s, ("", "") <- lex t] of
              [x] -> return x
              [] -> ioError (userError "Prelude.readIO: no parse")
              _ -> ioError (userError "Prelude.readIO: ambiguous parse")

readLn' :: (Read a) => IO a
readLn' = do { l <- getLine'; r <- readIO' l; return r }

main :: IO ()
main = do
  putChar 'a'
  putStr "bc"
  putStr' "bc"
  putStrLn "d"
  putStrLn' "d"
  print (1 :: Int, 'x')
  print' (1 :: Int, 'x')
  c <- getChar
  print c
  l1 <- getLine
  l2 <- getLine'
  print (l1, l2)
  n1 <- readLn
  n2 <- readLn'
  print (n1 + n2 :: Int)
  r1 <- readIO "4"
  r2 <- readIO' "4"
  print (r1 == (r2 :: Int))
  catch (readIO' "x" >>= \n -> print (n :: Int)) (\e -> putStrLn "no parse")
  catch (ioError (userError "u")) (\e -> print (not (null (show e)), e == e))
  s <- getContents
  print s
