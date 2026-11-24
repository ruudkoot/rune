{-# LANGUAGE PackageImports #-}
-- Data.Maybe (T10 chapter 21): base's functions (monomorphic); Functor, Monad, MonadPlus Maybe are the shim's.
module Data.Maybe (
    Maybe(Nothing, Just), isJust, isNothing, fromJust, fromMaybe, listToMaybe, maybeToList, catMaybes, mapMaybe, maybe
  ) where
import "base" Data.Maybe ( Maybe(Nothing, Just), isJust, isNothing, fromJust, fromMaybe, listToMaybe, maybeToList,
    catMaybes, mapMaybe, maybe )
