val mask:Word64.word=0wx7fffffff
val a:Word64.word=0w15148902
val multiplier:Word64.word=0w48271
val overloaded=a*multiplier
val qualified=Word64.*(a,multiplier)
val _=List.app(fn(name,w)=>TextIO.output(TextIO.stdOut,"WORD "^name^" "^Word64.toString w^" "^IntInf.toString(Word64.toLargeInt w)^"\n"))[("mask",mask),("a",a),("multiplier",multiplier),("overloaded",overloaded),("qualified",qualified),("masked",Word64.andb(qualified,mask)),("shifted",Word64.>>(qualified,0w31))]
val _=TextIO.output(TextIO.stdOut,"SUMMARY 1 checks, 0 failed\n")

val bit=Word64.<<(0w1,0w30)
val _=TextIO.output(TextIO.stdOut,"CHECK bit30="^Bool.toString(Word64.andb(mask,bit)<>0w0)^" mask-equivalence="^Bool.toString(mask=Word64.orb(bit,0wx3fffffff))^"\n")
val safeMask=Word64.-(Word64.<<(0w1,0w31),0w1)
val _=TextIO.output(TextIO.stdOut,"CHECK safeMask="^Word64.toString safeMask^" equivalent="^Bool.toString(safeMask=mask)^"\n")
