module Main where
import qualified Kernel as K
main=mapM_ (\(name,(x,y,z))->putStrLn(unwords[name,show x,show y,show z]))
 [("add",K.vecadd (1,2,3) (4,5,6)),
  ("sub",K.vecsub (1,2,3) (4,5,6)),
  ("mult",K.vecmult (1,2,3) (4,5,6)),
  ("cross",K.veccross (1,2,3) (4,5,6)),
  ("scale",K.vecscale (1,2,3) (-2)),
  ("norm",fst(K.vecnorm (3,4,0))),
  ("sum",K.vecsum [(1,2,3),(4,5,6),(7,8,9)]),
  ("ambient-default",K.ambientsurf []),
  ("body-default",K.bodysurf []),
  ("first-surface",K.ambientsurf[K.Diffuse (7,8,9),K.Ambient (1,2,3),K.Ambient (4,5,6)]),
  ("refract-front",snd(K.refractray 0.5 (0.6,0,-0.8) (0,0,1))),
  ("refract-back",snd(K.refractray 1.5 (0.6,0,0.8) (0,0,1))),
  ("refract-tir",snd(K.refractray 1.5 (sqrt 0.75,0,-0.5) (0,0,1))),
  ("empty-lights-shade",K.shade [] (K.Sphere (0,0,0) 0.5 [K.Ambient (0.2,0.3,0.4)]) (0,0,2) (0,0,-1) 1.5 (1,1,1))]
