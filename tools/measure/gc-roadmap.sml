(* GC experiment schedule. Each row preserves an original sampler argv. *)
structure MeasureGCRoadmap =
struct
  open MeasureCommon
  val plan=[
    ("h10",["h10-lat","-n","5","--","h10","what=lat"]),
    ("h10",["h10-l3","-n","5","--","h10","what=lat,latpg","huge=both","sizes=2M,3M,3.5M,4M,4.5M,5M,5.5M,6M,7M,8M,12M,16M,24M"]),
    ("h10",["h10-l3b","-n","3","--","h10","what=lat,latpg","huge=0","sizes=4M,6M,8M,12M,16M,24M"]),
    ("h10",["h10-bw","-n","5","--","h10","what=bw","sizes=8K,16K,32K,64K,128K,256K,512K,1M,2M,4M,8M,16M,32M,64M,256M"]),
    ("h2",["h2-small","-n","5","--","h2","live=32K,1M"]),
    ("h2",["h2-big","-n","3","--","h2","live=128M","size=16,32,64,256","reps_big=3"]),
    ("h8",["h8","-n","3","--","h8"]),
    ("h1",["h1","-n","3","-e","mem l2","-m","6291456","--","h1","trace=bootstrap"]),
    ("h1",["h1-huge","-n","3","-m","6291456","--","h1","trace=bootstrap","huge=1","pf=0","nursery=256K,1M,4M,16M,32M"]),
    ("h6",["h6","-n","3","--","h6"]),
    ("h3",["h3","-n","3","--","h3"]),
    ("h9",["h9","-n","5","--","h9"]),
    ("h7",["h7","-n","5","-m","6291456","--","h7"]),
    ("h5",["h5-boot","-n","2","-m","6291456","--","h5","trace=bootstrap","frag=$F","alloc=bump,immix,segfit,bestfit,nextfit","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-boot-ff","-n","1","-m","6291456","--","h5","trace=bootstrap","frag=$F","alloc=firstfit","nursery=1M","factor=2"]),
    ("h5",["h5-boot-factor","-n","1","-m","6291456","--","h5","trace=bootstrap","frag=$F","nursery=1M","factor=1.5,3","graph=0"]),
    ("h5",["h5-boot-line64","-n","1","-m","6291456","--","h5","trace=bootstrap","frag=$F","nursery=1M","alloc=immix","line=64","graph=0"]),
    ("h5",["h5-boot-line256","-n","1","-m","6291456","--","h5","trace=bootstrap","frag=$F","nursery=1M","alloc=immix","line=256","graph=0"]),
    ("h5",["h5-boot-exact","-n","1","-m","6291456","--","h5","trace=bootstrap","frag=$F","nursery=1M","alloc=immix","exact=1","graph=0"]),
    ("h5",["h5-compile-sigs","-n","1","-m","6291456","--","h5","trace=compile-sigs","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-runedoc-page","-n","1","-m","6291456","--","h5","trace=runedoc-page","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-mlyacc","-n","1","-m","6291456","--","h5","trace=mlton-mlyacc","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-knuth-bendix","-n","1","-m","6291456","--","h5","trace=mlton-knuth-bendix","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-barnes-hut","-n","1","-m","6291456","--","h5","trace=mlton-barnes-hut","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-lexgen","-n","1","-m","6291456","--","h5","trace=mlton-lexgen","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-nucleic","-n","1","-m","6291456","--","h5","trace=mlton-nucleic","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-mlton-ray","-n","1","-m","6291456","--","h5","trace=mlton-ray","frag=$F","nursery=256K,1M,4M","factor=2"]),
    ("h5",["h5-compile-sigs-min1M","-n","1","-m","6291456","--","h5","trace=compile-sigs","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-runedoc-page-min1M","-n","1","-m","6291456","--","h5","trace=runedoc-page","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-mlyacc-min1M","-n","1","-m","6291456","--","h5","trace=mlton-mlyacc","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-knuth-bendix-min1M","-n","1","-m","6291456","--","h5","trace=mlton-knuth-bendix","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-barnes-hut-min1M","-n","1","-m","6291456","--","h5","trace=mlton-barnes-hut","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-lexgen-min1M","-n","1","-m","6291456","--","h5","trace=mlton-lexgen","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-nucleic-min1M","-n","1","-m","6291456","--","h5","trace=mlton-nucleic","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5",["h5-mlton-ray-min1M","-n","1","-m","6291456","--","h5","trace=mlton-ray","frag=$F","nursery=256K,1M,4M","factor=2","min=1M","alloc=bump,immix,segfit,bestfit,nextfit"]),
    ("h5-ops",["h5-ops","-n","1","-m","6291456","--","h5","ops=$GCB_OPS","alloc=segfit,bestfit,nextfit,immix","majors=$OUT/ops/bootstrap.majors.tsv","frag=$F"])]
  fun main args =
    let val output=fromRoot "tests/out/gcbench" val ()=mkdirs output
        val frag=output ^ "/h5-frag.tsv" val majors=output ^ "/ops/bootstrap.majors.tsv"
        val choices=if null args then ["h10","h2","h8","h1","h6","h3","h9","h7","h5","h5-ops"] else args
        fun expand "$F"=frag | expand word=
          if word="frag=$F" then "frag=" ^ frag else if word="ops=$GCB_OPS" then "ops=" ^ env ("GCB_OPS","")
          else if word="majors=$OUT/ops/bootstrap.majors.tsv" then "majors=" ^ majors else word
        fun experiment name =
          let val rows=List.filter (fn (key,_) => key=name) plan
              val ()=if null rows then raise Usage ("gcbench-roadmap: no experiment " ^ name) else ()
          in if name="h5-ops" andalso env ("GCB_OPS","")="" then say "roadmap.sh: h5-ops needs GCB_OPS (gcsim's --ops stream); skipped\n" else
             (if name="h1" orelse name="h5" then need (env ("GCB_TRACES","")<>"",name ^ " needs GCB_TRACES (a directory of census traces)") else ();
              if name="h5" then write (frag,"") else if name="h5-ops" then (mkdirs (OS.Path.dir majors);write (majors,"")) else ();
              List.app (fn (_,args) => need (MeasureGCMeasure.main (List.map expand args)=0,"GC experiment sampler failed")) rows) end
    in List.app experiment choices;say "gcbench-roadmap: done; rune-measure gcbench-report writes the tables\n";0 end
end
