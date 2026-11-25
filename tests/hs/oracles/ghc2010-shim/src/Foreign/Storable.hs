{-# LANGUAGE PackageImports #-}
-- Foreign.Storable (T10 chapter 37): base's class (no superclass, the Report's methods).
module Foreign.Storable (
    Storable(sizeOf, alignment, peekElemOff, pokeElemOff, peekByteOff, pokeByteOff, peek, poke)
  ) where
import "base" Foreign.Storable
