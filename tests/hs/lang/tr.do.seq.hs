-- rows: tr.do.last tr.do.bind
-- Report 3.14: do {e} is e, do {e; ss} is e >> do {ss}, and do {p <- e; ss} binds through >>=: a user Monad sees >>
-- for the statement whose value is unused, >>= for the bound one.
module Main (main) where

newtype W a = W (a, String)

instance Monad W where
  return a = W (a, "")
  W (a, s) >>= f = let W (b, t) = f a in W (b, s ++ "[>>=]" ++ t)
  W (_, s) >> W (b, t) = W (b, s ++ "[>>]" ++ t)

tell :: String -> W ()
tell s = W ((), s)

logOf :: W a -> String
logOf (W (_, s)) = s

main :: IO ()
main = do
  putStrLn (logOf (do { tell "a"; tell "b"; x <- return (1 :: Int); tell (show x) }))
  putStrLn (logOf (tell "a" >> (tell "b" >> (return (1 :: Int) >>= \x -> tell (show x)))))
  putStrLn (logOf (do { tell "c" }))
