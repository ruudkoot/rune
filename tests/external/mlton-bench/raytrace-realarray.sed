# raytrace with its matrices as RealArray, the flat array of
# docs/plans/heap-layout.md's M8, where the program has `float array`: the
# sixteen reals of a transformation, made by Array.of_list and Array.make
# and read and written by Array.unsafe_get and Array.unsafe_set, all inside
# the signature and the structure of Matrix (lines 160 to 334 of the source).
160,334s/float array/RealArray.array/
160,334s/Array\.of_list/RealArray.fromList/
160,334s/Array\.unsafe_get/RealArray.sub/
160,334s/Array\.unsafe_set/RealArray.update/
160,334s/Array\.make/RealArray.array/
