-- The stub's syntax (tests/runner/hsroundtrip.sml): words, with an empty
-- item and a trailing comma that its parser drops.
module Main ( main , ) where {
  main = print ( f 1 ) ;
  f x = x ;
  ;
}
