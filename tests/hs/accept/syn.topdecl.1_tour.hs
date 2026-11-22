-- rows: syn.topdecl.2 syn.topdecl.3 syn.topdecl.4 syn.topdecl.5 syn.topdecl.6 syn.topdecl.7 syn.decl.1 syn.decl.2 syn.cdecls.1 syn.cdecl.1 syn.cdecl.2 syn.idecls.1 syn.idecl.1 syn.idecl.2 syn.gendecl.1 syn.gendecl.2 syn.gendecl.3 syn.ops.1 syn.vars.1 syn.fixity.1 syn.type.1 syn.btype.1 syn.atype.1 syn.atype.2 syn.atype.3 syn.atype.4 syn.atype.5 syn.gtycon.1 syn.gtycon.2 syn.gtycon.3 syn.gtycon.4 syn.gtycon.5 syn.context.1 syn.context.2 syn.class.1 syn.class.2 syn.scontext.1 syn.scontext.2 syn.simpleclass.1 syn.simpletype.1 syn.constrs.1 syn.constr.1 syn.constr.2 syn.constr.3 syn.newconstr.1 syn.newconstr.2 syn.fielddecl.1 syn.deriving.1 syn.dclass.1 syn.inst.1 syn.inst.2 syn.inst.3 syn.inst.4 syn.inst.5 syn.r.scontext.parens syn.r.deriving.single syn.r.deriving.qualified syn.r.inst.spelled syn.r.type.tupcon syn.r.constr.arity syn.r.constr.strict.infix syn.r.fielddecl.strict syn.r.ctx.class.app syn.r.vars.nonempty
-- Report 9.5: topdecl in each of its forms, and the declarations, types, contexts, constructors, deriving clauses and
-- instance heads they hold, each form at least once.
module Main (main) where

infixr 5 :+:, +++
infixl 6 <+>
infix 4 =:=

type Pair a = (a, a)
type Fun = Int -> Int

data (Eq a) => Set a = Set [a] deriving (Show)
data T a = L | Nd !a (T a) | a :+: (T a) | R { rf, rg :: !Int, rh :: Maybe a } deriving (Eq, Show)
data S = !Int :* !Int | Maybe Int :- Maybe Bool
data E = E deriving Eq
data D = D deriving ()
data Q = Q deriving Prelude.Show
newtype N = N Int deriving (Eq, Ord)
newtype M a = M { unM :: [a] }

class (Eq a) => C a where
  infixl 7 <*.>
  (<*.>) :: a -> a -> a
  op, op2 :: a -> Bool
  op x = x == x
  op2 = op
  ;

class () => K a where
  k :: a -> ()

instance C Int where
  (<*.>) a b = a * b
  op2 = const True
  ;

instance (Eq a) => C (T a) where
  x <*.> _ = x

instance K () where k _ = ()
instance K [a] where k _ = ()
instance K (a, b) where k _ = ()
instance K (a -> b) where k _ = ()
instance K (Maybe a) where k _ = ()
instance K Bool where k _ = ()
instance K ((,,) a b c) where k _ = ()

default (Integer, Double)

(+++) :: [a] -> [a] -> [a]
xs +++ ys = xs ++ ys

(<+>), (=:=) :: Int -> Int -> Int
a <+> b = a + b
a =:= b = a - b

g :: (Eq (m a), Monad m) => m a -> m a -> Bool
g x y = x == y

h :: () => [Int] -> (Int, Bool) -> Pair Int -> Fun -> (->) Int Int
h _ _ _ f = f

e :: [] Int -> (,) Int Bool -> (,,) Int Int Int -> (Int)
e xs _ _ = length xs

main :: IO ()
main = do
  print (L :: T Int, 1 <+> 2 =:= 3, [1] +++ [2] +++ [3 :: Int], g [1 :: Int] [1])
  print (E == E, e [1] (1, True) (1, 2, 3), k (), 1 <*.> (2 :: Int))
