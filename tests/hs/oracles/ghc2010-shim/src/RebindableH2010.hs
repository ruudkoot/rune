{-# LANGUAGE PackageImports #-}
-- RebindableH2010: the names RebindableSyntax looks up, for a program module whose own Prelude import does not bring
-- them all (an import list, or a qualified Prelude only).  The judge adds `import RebindableH2010` to such a module.
module RebindableH2010 (fromInteger, fromRational, negate, (>>=), (>>), fail, ifThenElse, (==)) where
import "base" Prelude ((==))
import H2010.Classes
