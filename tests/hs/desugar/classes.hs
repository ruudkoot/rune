-- Classes and instances as dictionaries (4.3): a superclass taken from a subclass's dictionary, a default method used
-- where an instance gives none and overridden where it does, an instance with a context, a method with a type variable
-- and a context of its own, and a class over a type constructor.
module Main (main) where

class Named a where
  name :: a -> String
  greet :: a -> String
  greet x = "hello " ++ name x

class Named a => Ranked a where
  rank :: a -> Int
  describe :: a -> String
  describe x = name x ++ " " ++ show (rank x)

data Cat = Cat
data Dog = Dog Int

instance Named Cat where
  name _ = "cat"

instance Named Dog where
  name (Dog n) = "dog" ++ show n
  greet d = "woof " ++ name d

instance Ranked Dog where
  rank (Dog n) = n * 10

instance Named a => Named [a] where
  name xs = concatMap name xs

instance Named a => Named (Maybe a) where
  name Nothing = "nobody"
  name (Just x) = "maybe " ++ name x

class Container f where
  empty :: f a
  insert :: a -> f a -> f a
  toL :: f a -> [a]
  size :: f a -> Int
  size c = length (toL c)

newtype Box a = Box [a]

instance Container Box where
  empty = Box []
  insert x (Box xs) = Box (x : xs)
  toL (Box xs) = xs

class Pretty a where
  pretty :: a -> String
  prettyWith :: Pretty b => b -> a -> String
  prettyWith b a = pretty b ++ ":" ++ pretty a

instance Pretty Int where
  pretty n = show n

describeTwice :: Ranked a => a -> String
describeTwice x = describe x ++ "/" ++ greet x

main :: IO ()
main = do
  putStrLn (greet Cat)
  putStrLn (greet (Dog 2))
  putStrLn (describe (Dog 3))
  putStrLn (describeTwice (Dog 4))
  putStrLn (name [Cat, Cat])
  putStrLn (greet (Just (Dog 5)))
  putStrLn (name (Nothing :: Maybe Cat))
  print (size (insert 'a' (insert 'b' (empty :: Box Char))))
  print (sum (toL (insert (1 :: Int) (insert 2 empty) :: Box Int)))
  putStrLn (prettyWith (1 :: Int) (2 :: Int))
