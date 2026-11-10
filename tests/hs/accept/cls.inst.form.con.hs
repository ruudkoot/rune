-- rows: cls.inst.form.app cls.inst.form.tuple cls.inst.form.list cls.inst.form.fun cls.inst.form.parencon
-- Report 4.3.2: inst -> gtycon | ( gtycon tyvar1 ... tyvark ) | ( tyvar1 , ... , tyvark ) | [ tyvar ] | ( tyvar1 -> tyvar2 ),
-- with k = 0 in the parenthesised form too, and the special type constructors written prefix.
module Main (main) where

data T a b = T
data U = U
class C a
class K f where
  k :: f a -> ()

instance C Int
instance C ()
instance K []
instance K ((->) r)
instance C (T a b)
instance C (Maybe a)
instance K ((,) a)
instance C (a, b)
instance C (a, b, c)
instance C [a]
instance C (a -> b)
instance C (U)

main :: IO ()
main = return ()
