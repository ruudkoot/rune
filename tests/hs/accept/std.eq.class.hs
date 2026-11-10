-- rows: std.ord.class std.read.class std.show.class std.enum.class std.functor.class std.monad.class std.bounded.class std.bounded.noord std.text.function.vacuous
-- Report 6.3: the Prelude's classes and their methods: instances defining one of Eq's two, Ord's compare alone, Read's
-- readsPrec alone, Show's show alone and showsPrec alone, Enum's toEnum and fromEnum, Functor's fmap, Monad's
-- >>= and return, Bounded with no Ord, and Show for functions.
module Main (main) where

data E = E1 | E2
instance Eq E where
  E1 == E1 = True
  E2 == E2 = True
  _ == _ = False

data F = F
instance Eq F where
  _ /= _ = False
instance Ord F where
  compare _ _ = EQ

data R = R
instance Read R where
  readsPrec _ s = [(R, s)]
instance Show R where
  show _ = "R"

data S = S
instance Show S where
  showsPrec _ _ = showString "S"

data N = N0 | N1
instance Enum N where
  toEnum 0 = N0
  toEnum _ = N1
  fromEnum N0 = 0
  fromEnum N1 = 1

newtype Box a = Box a
instance Functor Box where
  fmap f (Box a) = Box (f a)

newtype Id a = Id a
instance Monad Id where
  Id a >>= f = f a
  return = Id

data B = B
instance Bounded B where
  minBound = B
  maxBound = B

instance Show (a -> b) where
  show _ = "<function>"

unId :: Id a -> a
unId (Id a) = a

unBox :: Box a -> a
unBox (Box a) = a

main :: IO ()
main = do
  print (E1 == E2, F == F, F < F, read "R" :: R, S)
  print (fromEnum (succ N0), unBox (fmap not (Box True)), unId (Id 1 >>= \x -> return (x + 1)), id)
  case (minBound :: B) of B -> return ()
