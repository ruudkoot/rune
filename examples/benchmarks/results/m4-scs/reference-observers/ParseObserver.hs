module Main where
import qualified Parse
main=do
 mapM_ (\s->print(s,Parse.parse_exact s)) ["10n","400p","- 3. 25m","1.",".5","1E","1e3","01","1 .2","  1.25u  "]
 mapM_ (\s->print(s,Parse.parse_integer s)) ["345","-345","- 345","+345","01","345 "]
