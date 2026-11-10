-- rows: dec.scope.decls.let dec.scope.decls.where dec.decls.empty dec.cdecls.empty dec.idecls.empty dec.gendecl.empty dec.idecl.empty dec.vars.many dec.fix.ops.many def.decl.form
-- Report 4: decls (signatures, fixity declarations, bindings) stand at the top, in a let and in a where; a declaration
-- list, a class body and an instance body may be empty, an empty declaration may stand among them, vars and ops
-- take several names; 4.3.4: default with zero, one and two types.
module Main (main) where

infixl 6 +++, -+-, `foo`
(+++), (-+-) :: Int -> Int -> Int
x +++ y = x + y
x -+- y = x - y
foo :: Int -> Int -> Int
foo = (*)

class C a where {}
instance C Int where {}
class D a where { d :: a -> Int }
instance D Int where { ; }
instance D Bool where { ; d _ = 0 ; ; }

default ()

a, b :: Int
a = let { ; ; infixr 5 <> ; (<>) :: Int -> Int -> Int ; x <> y = x ; z = 1 <> 2 ; ; } in z
b = c where { infixl 7 ** ; (**) :: Int -> Int -> Int ; x ** y = x ; c = 1 ** 2 }

e :: Int
e = let {} in 1

f :: Int
f = 1 where {}

main :: IO ()
main = print (a +++ b -+- e `foo` f)
