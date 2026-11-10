-- A monad of the program's own, a state monad, through its dictionary:
-- constructor classes, default methods (>>) and superclass-free returns,
-- specialised and simplified at -O2.
-- fuel: every lint holds and it prints the same whatever rewrite it stops after
module Main where

newtype State s a = State (s -> (a, s))

runState :: State s a -> s -> (a, s)
runState (State f) = f

instance Monad (State s) where
  return a = State (\s -> (a, s))
  m >>= k = State (\s -> let (a, s') = runState m s in runState (k a) s')

get :: State s s
get = State (\s -> (s, s))

put :: s -> State s ()
put s = State (\_ -> ((), s))

tick :: State Int Int
tick = do
  n <- get
  put (n + 1)
  return n

counter :: Int -> State Int [Int]
counter 0 = return []
counter k = do
  a <- tick
  rest <- counter (k - 1)
  return (a : rest)

sumM :: Monad m => [m Int] -> m Int
sumM [] = return 0
sumM (m : ms) = m >>= \a -> sumM ms >>= \b -> return (a + b)

main :: IO ()
main = do
  print (runState (counter 5) 10)
  print (fst (runState (sumM [tick, tick, tick]) 1))
  r <- sumM [return 1, return 2, return 3]
  print r
  print (sumM [Just 1, Just 2], sumM [Just 1, Nothing])
