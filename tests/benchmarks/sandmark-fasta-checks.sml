structure SandmarkFastaTests =
struct
 fun contents path=BenchFastaCycleCheck.read path
 val alu=contents "alu.data"
 val iub=contents "fasta3-iub.cycle"
 val homo=contents "fasta3-homo.cycle"
 fun collect kernel n=
   let val chunks=ref([]:string list)
       fun text(data,start,count)=chunks:=String.substring(data,start,count):: !chunks
       fun buffer(data,start,count)=chunks:=String.implode(List.tabulate(count,fn i=>CharArray.sub(data,start+i))):: !chunks
       fun character c=chunks:=String.str c:: !chunks
       val _=kernel n {text=text,buffer=buffer,character=character}
   in String.concat(List.rev(!chunks))end
 val _=T.check("sandmark-fasta/embedded-alu",fn()=>BenchSandmarkFasta.alu=alu)
 val _=T.check("sandmark-fasta/both-original-smokes",fn()=>collect BenchSandmarkFasta.run3 151=contents "fasta3-smoke.output"andalso collect BenchSandmarkFasta.run6 151=contents "fasta6-smoke.output")
 val _=T.check("sandmark-fasta/reviewed-cycle-oracle",fn()=>BenchFastaCycleCheck.run BenchSandmarkFasta.run3 151 alu iub homo=BenchFastaCycleCheck.run BenchSandmarkFasta.run6 151 alu iub homo)
 val _=T.check("sandmark-fasta/line-boundary-variants",fn()=>List.all(fn n=>collect BenchSandmarkFasta.run3 n=collect BenchSandmarkFasta.run6 n)[1,12,20,59,60,61,143,144,145,287,288])
 val _=T.check("sandmark-fasta/circular-boundary-index",fn()=>BenchSandmarkFasta.writeCircular(fn _=>())287 227 60=287)
 val _=T.check("sandmark-fasta/rejects-truncated-output",fn()=>(ignore(BenchFastaCycleCheck.run(fn _=>fn _=>())151 alu iub homo);false)handle Fail _=>true)
 val _=T.check("sandmark-fasta/rejects-extra-output",fn()=>(ignore(BenchFastaCycleCheck.run(fn n=>fn out=>(BenchSandmarkFasta.run3 n out;(#character out) #"x"))151 alu iub homo);false)handle Fail _=>true)
 val _=T.check("sandmark-fasta/reset-between-runs",fn()=>collect BenchSandmarkFasta.run3 151=collect BenchSandmarkFasta.run3 151)
end
structure SandmarkFastaOracleNegative =
struct
 val _=T.check("sandmark-fasta/rejects-wrong-cycle-byte",fn()=>
   let val alu=BenchFastaCycleCheck.read "alu.data"
       val iub=BenchFastaCycleCheck.read "fasta3-iub.cycle"
       val homo=BenchFastaCycleCheck.read "fasta3-homo.cycle"
       val bad=String.str(if String.sub(iub,0)= #"a"then #"c"else #"a")^String.extract(iub,1,NONE)
   in(ignore(BenchFastaCycleCheck.run BenchSandmarkFasta.run3 151 alu bad homo);false)handle Fail _=>true end)
end
