-- Report: fail is a Monad method; a failing pattern in do calls the monad's fail (here Maybe: Nothing).
module Main where
data M a = M (Maybe a) deriving Show
instance Monad M where
  return = M . Just
  M Nothing >>= _ = M Nothing
  M (Just a) >>= k = k a
  fail _ = M Nothing
main = print (do { (x:_) <- return []; return (x :: Int) } :: M Int)
