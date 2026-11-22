-- rows: pre.fixity.8caretccaretcaretcstarstar pre.fixity.7starcslashcquotcremcdivcmod pre.fixity.6pluscminus pre.fixity.4eqeqcslasheqcltclteqcgteqcgt pre.fixity.3ampamp pre.fixity.2barbar pre.fixity.1gtgtcgtgteq pre.fixity.1eqltlt pre.fixity.0dollarcdollarbangcseq pre.r.colon.fixity pre.r.fixity.bindm
-- Report 8: the Prelude's fixities, each shown by the value of an unparenthesised mix: infixr 9 ., infixr 8 ^ ^^ **,
-- infixl 7 * / quot rem div mod, infixl 6 + -, infixr 5 : ++, infix 4 comparisons, infixr 3 &&, infixr 2 ||,
-- infixl 1 >> >>=, infixr 1 =<< (erratum of July 2004), infixr 0 $ $! seq.
module Main (main) where

main :: IO ()
main = do
  print ((+ 1) . (* 2) $ 3 :: Int)
  print (2 ^ 3 ^ 2 :: Int, 2 * 3 ^ 2 :: Int, 2 ^^ 2 ^ 2 :: Double, 2 ** 1 ** 3 :: Double)
  print (100 `div` 5 `div` 2 :: Int, 7 - 2 * 3 :: Int, 100 `quot` 7 `rem` 4 :: Int, 9 / 3 / 3 :: Double, 7 `mod` 4 * 2 :: Int)
  print (7 - 2 - 1 :: Int, 1 + 2 * 3 :: Int)
  print (1 + 2 == (3 :: Int) && 2 < (3 :: Int) || False, 1 : 2 : [] ++ [3 :: Int], 1 + 1 : [2 :: Int])
  print (False && False || True, True || True && False)
  return (1 :: Int) >>= print >> print (2 :: Int)
  print =<< return (3 :: Int)
  print (Just 4 >>= (\x -> return (x + 1)) :: Maybe Int, (\x -> Just (x * 2)) =<< (\x -> Just (x + 1)) =<< Just (5 :: Int))
  print (1 `seq` 2 `seq` (3 :: Int), negate $! abs $ (-4 :: Int))
