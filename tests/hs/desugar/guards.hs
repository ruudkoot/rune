-- Guards and where (3.17.3 rule (c), 4.4.3): a where binds over all of a clause's guards; where every guard fails the
-- match goes on to the next alternative or clause; a pattern binding with no guard that holds is an error, on demand.
module Main (main) where

classify :: Int -> String
classify n
  | n < lo = "low"
  | n > hi = "high"
  where lo = 10
        hi = 20
classify 15 = "fifteen"
classify _ = "middle"

pick :: Maybe Int -> String
pick m = case m of
  Just n | n > 0 -> "positive"
         | n < 0 -> "negative"
  Just _ -> "zero"
  Nothing -> "none"

x :: Int
x | False = 1

main :: IO ()
main = do
  putStrLn (classify 3)
  putStrLn (classify 30)
  putStrLn (classify 15)
  putStrLn (classify 12)
  putStrLn (pick (Just 2))
  putStrLn (pick (Just (-2)))
  putStrLn (pick (Just 0))
  putStrLn (pick Nothing)
  print (seq (const (1 :: Int) x) (2 :: Int))
