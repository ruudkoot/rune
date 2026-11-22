-- M24 and a newtype (R's, D51's measurement): a function strict in a value of a type variable, its worker taking it
-- evaluated (`!a`), its wrapper's case on it the newtype's when the wrapper is inlined at one, which Core has as a case
-- on what the newtype wraps; its binder, the newtype's value evaluated, is no atom of Core, so the copy is not made
-- there and the call stays the wrapper's (CoreSimplifySimp.losesEval). Caught by CoreLint at --lint=2: "may be
-- unevaluated where !Main.A is wanted, an argument of %w:Main.keep". The same of a constructor's strict field of a type
-- variable given a newtype (M23), and of a newtype that is a monad.
module Main (main) where

newtype A = A Double deriving (Show)

keep :: Int -> a -> a
keep 0 a = a
keep n a = keep (n - 1) a

data P a = P !a

unP :: P a -> a
unP (P a) = a

newtype St a = St (Int -> (a, Int))

instance Monad St where
  return a = St (\s -> (a, s))
  St m >>= k = St (\s -> case m s of (a, s') -> let St m' = k a in m' s')

tick :: St ()
tick = St (\s -> ((), s + 1))

run :: St a -> Int -> (a, Int)
run (St m) s = m s

again :: Monad m => Int -> m a -> m a
again 0 a = a
again n a = again (n - 1) a

main :: IO ()
main = do
  print (keep 3 (A (negate 1.5)))
  mapM_ (print . unP) [P (A 2), P (A (negate 0.5))]
  print (snd (run (again 3 (tick >> tick)) 0), snd (run (unP (P (tick >> tick >> tick))) 0))
