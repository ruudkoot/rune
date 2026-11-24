-- H2010Default: a GHC 9.4 defaulting plugin that applies the Haskell 2010 Report's defaulting rule (T10 4.3.4) to the
-- shim's classes, which GHC's own rule cannot see (it knows base's numeric classes by their keys).
--
-- A type variable v is defaultable when every constraint that mentions it has the form C v, at least one such C is a
-- numeric class (the shim's Num or a subclass: Real, Integral, Fractional, Floating, RealFrac, RealFloat, Bits), and
-- every C is a class of the Prelude or a standard library: one of the shim's, or base's Eq, Ord, Show, Read, Enum,
-- Bounded, Ix, Storable.  The candidates are the module's default declaration, or (Integer, Double); GHC tries them
-- in order and takes the first that satisfies every constraint (disambigGroup).
module H2010Default (plugin) where

import GHC.Plugins
import GHC.Tc.Types (TcGblEnv(tcg_default), FillDefaulting, DefaultingProposal(..))
import qualified GHC.Tc.Types as T
import GHC.Core.Class (Class)
import GHC.Tc.Plugin (getEnvs)
import GHC.Tc.Types.Constraint
import GHC.Tc.Solver (approximateWC)
import GHC.Core.Predicate
import GHC.Builtin.Types (integerTy, doubleTy)
import GHC.Tc.Utils.TcType (isMetaTyVar, tyCoVarsOfTypeList)
import GHC.Data.Bag (bagToList)
import Data.List (nub)
import qualified Data.Map as M

plugin :: Plugin
plugin = defaultPlugin { defaultingPlugin = \_ -> Just dp, pluginRecompile = purePlugin }

dp :: T.DefaultingPlugin
dp = T.DefaultingPlugin { T.dePluginInit = return (), T.dePluginStop = \_ -> return (), T.dePluginRun = \_ -> run }

shimUnit :: String
shimUnit = "haskell2010-report-1.0"

numeric, shimStandard, baseStandard :: [String]
numeric = ["Num", "Real", "Integral", "Fractional", "Floating", "RealFrac", "RealFloat", "Bits"]
shimStandard = numeric ++ ["Functor", "Monad", "MonadPlus"]
baseStandard = ["Eq", "Ord", "Show", "Read", "Enum", "Bounded", "Ix", "Storable"]

classKind :: Class -> Maybe Bool          -- Just isNumeric for a standard class, Nothing otherwise
classKind cls =
  let n = getName cls
      occ = getOccString n
      unit = case nameModule_maybe n of
               Just m -> unitString (moduleUnit m)
               Nothing -> ""
  in if unit == shimUnit && occ `elem` shimStandard then Just (occ `elem` numeric)
     else if (unit == "base" || take 5 unit == "base-" || take 9 unit == "ghc-prim" ) && occ `elem` baseStandard
       then Just False
     else Nothing

run :: FillDefaulting
run wanteds = do
  (gbl, _) <- getEnvs
  let cts = bagToList (approximateWC False wanteds)
      cands = case tcg_default gbl of
                Nothing -> [integerTy, doubleTy]
                Just tys -> tys
      unary ct = case classifyPredType (ctPred ct) of
                   ClassPred cls [ty] | Just tv <- getTyVar_maybe ty -> Just (tv, (cls, ct))
                   _ -> Nothing
      bad = nub [ tv | ct <- cts, Nothing <- [unary ct], tv <- tyCoVarsOfTypeList (ctPred ct) ]
      groups = M.toList (M.fromListWith (++) [ (tv, [x]) | ct <- cts, Just (tv, x) <- [unary ct] ])
      ok (tv, xs) = isMetaTyVar tv && tv `notElem` bad &&
                    all (\(c, _) -> classKind c /= Nothing) xs &&
                    any (\(c, _) -> classKind c == Just True) xs
  return [ DefaultingProposal { deProposalTyVar = tv, deProposalCandidates = cands, deProposalCts = map snd xs }
         | g@(tv, xs) <- groups, ok g ]
