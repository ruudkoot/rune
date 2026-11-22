-- rows: mod.imp.list.trailing mod.imp.empty mod.imp.as.varid mod.imp.qualified.varid mod.imp.hiding.varid
-- Report 5.2, 5.3: an export list and an import list may end with a comma; an import declaration may be empty; as,
-- qualified and hiding are varids, special only in an import declaration.
module Main (main,) where { ; import Char (ord,) ; ; import qualified Char as C hiding (chr) ;
as :: Int ; as = 1 ; qualified :: Int ; qualified = 2 ; hiding :: Int ; hiding = 3 ;
main :: IO () ; main = print (as + qualified + hiding + ord 'a') }
