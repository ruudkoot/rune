(* The oracle of what a language server keeps (docs/language-server.md, Keeping
   what is computed): one analysis context lives through a list of edits, and
   after each a fresh context analyses the same inputs. Every fact, occurrence,
   type, diagnostic and query must agree, whichever way the kept context got
   there; a difference is the failure that keeping can hide.

   Usage: rune-lsp-oracle --lib DIR --build FILE --scenarios FILE --out FILE
            [--focus] [--sample N] [--no-fresh] [--collect] [--require PATH,...]
            [--record FILE | --against FILE] [--share] [--store DIR]

   A scenario is a line of tab-separated fields:
     NAME  REPS  FILE-SUFFIX  KIND  [ARG1  [ARG2]]
   and a line "+  FILE-SUFFIX  KIND ..." adds another edit to the one above it.
   FILE-SUFFIX names the last input that ends so: LAST the last, FIRST the
   first; it may also name a build file. KIND:
     append             a comment at the end
     prepend            a comment at the start
     appendtext ARG1    ARG1 at the end, $N the repetition
     replace ARG1 ARG2  the first ARG1 made ARG2, $N the repetition
     toggle ARG1 ARG2   as replace on odd repetitions, the original on even
     new ARG1           a new file of that name beside the input, holding ARG1
     complete ARG1      a query, at the end of the first ARG1
     cancel ARG1        the edit's next check is cancelled at poll ARG1 first
   In ARG1 and ARG2, \n is a newline. After its repetitions a scenario's files
   go back and one more check settles them.

   --focus keeps only the edited file open, as an editor does, and the units
   compared that are closed are opened, from their notes where those hold.
   A fresh context keeps every file open, so that what it says of a unit is
   its elaboration's (but against a record, below, where it keeps the edited
   files alone). --sample N compares N units besides the edited one, every
   one without it. --no-fresh times the kept context alone.
   --collect collects after each check, and reports what lives.
   A corpus too large for two contexts at once is held to its oracle in two
   runs: --record keeps the context and writes what each check gave, as digests;
   --against, with the same scenarios, analyses each check's inputs afresh, one
   at a time, and compares.
   --share has the kept context share (C.Analysis.share): another context
   over the same build checks first, and the kept one, with no file open at
   first, takes the libraries' units from what that one left; the fresh ones
   share nothing.
   --store DIR has the kept context read the store in DIR (C.Analysis.store),
   a compile's of the build: another context over it checks first, with no
   file open, and writes the sidecars of the units it elaborates there; the
   kept one, with no file open at first, takes the units whose entries and
   sidecars hold from it. Without it the kept context reads no store, and
   the fresh ones never do.
   --require fails a run that did not take each of the paths named:
   placed walked rebound loaded cutoff broken failed cancelled query opened
   shared stored. *)
structure RuneLspOracle =
struct
  structure C=CompilerApi
  structure A=C.Analysis
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun num n=Int.toString n
  fun say text=(print text;TextIO.flushOut TextIO.stdOut)
  fun substitute (text,old,new)=
    let val (before',found)=Substring.position old (Substring.full text)
    in if Substring.isEmpty found then raise Fail ("no such text: " ^ old)
       else Substring.string before' ^ new ^ String.extract (text,Substring.size before'+size old,NONE) end
  fun fields (separator,text)=String.fields (fn c => c=separator) text
  (* a string with each $N made n *)
  fun expand (text,n)=
    let val pieces=ref [] val at=ref 0 val start=ref 0
        val count=size text
    in while !at<count do
         if !at+1<count andalso String.sub (text,!at)= #"$" andalso String.sub (text,!at+1)= #"N" then
           (pieces:=num n::String.substring (text,!start,!at- !start):: !pieces;at:= !at+2;start:= !at)
         else at:= !at+1;
       String.concat (List.rev (String.extract (text,!start,NONE):: !pieces)) end
  fun unescape text=
    let fun go ([],kept)=String.implode (List.rev kept)
          | go (#"\\" :: #"n" :: rest,kept)=go (rest,#"\n"::kept)
          | go (c::rest,kept)=go (rest,c::kept)
    in go (String.explode text,[]) end
  type edit={suffix:string,kind:string,arguments:string list}
  type scenario={name:string,repetitions:int,edits:edit list}
  fun parseScenarios text=
    let fun line (text,all)=
          if text="" orelse String.isPrefix "#" text then all else
          case fields (#"\t",text) of
            "+"::suffix::kind::arguments => (case all of
                {name,repetitions,edits}::rest =>
                  {name=name,repetitions=repetitions,edits=edits @ [{suffix=suffix,kind=kind,arguments=arguments}]}::rest
              | [] => raise Fail "a + line with no scenario")
          | name::repetitions::suffix::kind::arguments =>
              {name=name,repetitions=valOf (Int.fromString repetitions),edits=[{suffix=suffix,kind=kind,arguments=arguments}]}::all
          | _ => raise Fail ("not a scenario: " ^ text)
    in List.rev (List.foldl line [] (fields (#"\n",text))):scenario list end
  fun hex text=Hex.fromBytes (Sha256.digest text)
  fun location (NONE:A.location option)="-"
    | location (SOME {file,start,stop})=file ^ ":" ^ num start ^ ":" ^ num stop
  fun occurrenceText (o':A.occurrence)=String.concatWith "|" [#unit o',#file o',num (#start o'),num (#stop o'),#kind o',#name o',
    String.concatWith "." (#path o'),getOpt (#binding o',"-"),location (#definition o'),location (#declaration o'),
    Bool.toString (#isDefinition o'),Bool.toString (#derived o')]
  (* what occurrences say without what a definition's place in another file does *)
  fun looseText (o':A.occurrence)=String.concatWith "|" [#unit o',#file o',num (#start o'),num (#stop o'),#kind o',#name o',
    String.concatWith "." (#path o'),Bool.toString (#isDefinition o'),Bool.toString (#derived o')]
  fun factText (f:A.fact)=String.concatWith "|" [#unit f,#file f,num (#start f),num (#stop f),#ty f,Bool.toString (#derived f),
    String.concatWith "," (#constructors f),String.concatWith ";" (List.map (String.concatWith ",") (#arguments f))]
  fun typeText (t:A.typeDefinition)=String.concatWith "|" [#id t,location (#definition t),location (#declaration t),location (#implementation t)]
  fun diagnosticText (d:C.diagnostic)=String.concatWith "|" [#severity d,#file d,num (#start d),num (#stop d),num (#line d),num (#column d),#message d]
  fun candidateText (c:A.candidate)=String.concatWith "|" [#name c,#kind c,getOpt (#detail c,"-"),location (#definition c),
    String.concatWith ";" (List.map (String.concatWith ",") (#arguments c))]
  val paths=["placed","walked","rebound","loaded","cutoff","broken","failed","cancelled","query","opened","shared","stored"]
  fun main arguments =
    let val lib=ref "" val build=ref "" val scenariosFile=ref "" val out=ref ""
        val focusing=ref false val fresh=ref true val sample=ref ~1 val required=ref [] val collecting=ref false
        val recording=ref NONE : TextIO.outstream option ref
        val expected=ref [] : string list ref
        val againstRecord=ref false
        val shares=ref false
        val storeDir=ref NONE : string option ref
        fun options [] = ()
          | options ("--lib"::value::rest)=(lib:=value;options rest)
          | options ("--build"::value::rest)=(build:=value;options rest)
          | options ("--scenarios"::value::rest)=(scenariosFile:=value;options rest)
          | options ("--out"::value::rest)=(out:=value;options rest)
          | options ("--focus"::rest)=(focusing:=true;options rest)
          | options ("--no-fresh"::rest)=(fresh:=false;options rest)
          | options ("--collect"::rest)=(collecting:=true;options rest)
          | options ("--record"::file::rest)=(recording:=SOME (TextIO.openOut file);options rest)
          | options ("--against"::file::rest)=
              (expected:=List.filter (fn line => line<>"") (fields (#"\n",read file));againstRecord:=true;options rest)
          | options ("--sample"::value::rest)=(sample:=valOf (Int.fromString value);options rest)
          | options ("--require"::value::rest)=(required:=fields (#",",value);options rest)
          | options ("--share"::rest)=(shares:=true;options rest)
          | options ("--store"::dir::rest)=(storeDir:=SOME dir;options rest)
          | options (other::_)=raise Fail ("unknown option: " ^ other)
        val ()=options arguments
        val compiler=C.session {lib=SOME (!lib),flags=[]}
        val output=TextIO.openOut (!out)
        fun emit fields=(TextIO.output (output,Json.encode (Json.Object fields) ^ "\n");TextIO.flushOut output)
        val overlays=ref [] : (string*string) list ref
        fun overlay file=Option.map #2 (List.find (fn (name,_) => name=file) (!overlays))
        fun textOf file=case overlay file of SOME text => text | NONE => read file
        fun setOverlay (file,text)=overlays:=(file,text)::List.filter (fn (name,_) => name<>file) (!overlays)
        fun dropOverlay file=overlays:=List.filter (fn (name,_) => name<>file) (!overlays)
        val workspaceFile=C.Workspace.find {file= !build,windows=false}
        (* read again where a build's text has changed *)
        val planned=ref NONE : (string*C.Project.t) option ref
        fun project ()=
          let val key=String.concat (List.concat (List.map (fn (file,text) =>
                if String.isSuffix ".build" file then [file,text] else [file]) (!overlays)))
          in case !planned of SOME (prior,value) => if prior=key then value else plan key | NONE => plan key end
        and plan key=
          let val value=C.Project.read (compiler,{file= !build,workspace=workspaceFile,variables=[],windows=false,
                overlays=List.map (fn (file,text) => {file=file,text=text}) (!overlays)})
          in planned:=SOME (key,value);value end
        val memo=ref [] : (string*string*string) list ref
        fun disk (file,mode)=case List.find (fn (name,other,_) => name=file andalso other=mode) (!memo) of
            SOME (_,_,text) => text
          | NONE =>
              let val bytes=read file
                  val text=if mode="unicode=latin1" then String.translate (fn byte => Utf8.encode (Char.ord byte)) bytes else bytes
              in memo:=(file,mode,text):: !memo;text end
        fun inputs ()=List.map (fn source:C.Project.source =>
          {file= #file source,mode= #mode source,annotations= #annotations source,revision="",
           text=case overlay (#file source) of SOME text => text | NONE => disk (#file source,#mode source)}:A.input)
          (C.Project.sources (project ()))
        val context=A.create (compiler,{context="kept"})
        val ()=A.store (context,!storeDir)
        val placeholder=ref NONE : A.snapshot option ref
        val taken=ref [] : string list ref
        fun took path=if List.exists (fn other => other=path) (!taken) then () else taken:=path:: !taken
        val disagreements=ref 0
        val checks=ref 0
        val bindingsApart=ref 0
        fun checkIn (analysis,cancelled)=A.check (analysis,{project=SOME (project ()),inputs=inputs (),cancelled=cancelled})
        val ()=if not (!shares) then () else
          let val seed=A.create (compiler,{context="seed"})
              val pool=A.pool ()
          in A.store (seed,NONE);A.share (seed,SOME pool);A.focus (seed,SOME []);ignore (checkIn (seed,fn () => false));A.close seed;
             (* an open unit is elaborated where a walk reaches it, and never
                taken from another context: none is open at first *)
             A.share (context,SOME pool);A.focus (context,SOME []) end
        (* the store's sidecars, from an analysis of the files as they are *)
        val ()=case !storeDir of NONE => () | SOME dir =>
          let val seed=A.create (compiler,{context="seed"})
          in A.store (seed,SOME dir);A.focus (seed,SOME []);ignore (checkIn (seed,fn () => false));A.close seed;
             A.focus (context,SOME []) end
        fun never ()=false
        (* a seeded choice of units, the same on every run *)
        val seed=ref 1
        fun next limit=(seed:=(!seed*1103515245+12345) mod 2147483648;if limit<=0 then 0 else !seed mod limit)
        (* What a check answers, by a label that says where to ask again: the
           whole, and each chosen unit *)
        fun answers (snapshot:A.snapshot,labels)=
          let fun unitOf ordinal=A.unitAt (snapshot,{ordinal=ordinal})
              fun answer "diagnostics"=List.map diagnosticText (A.diagnostics snapshot)
                | answer "types"=List.map typeText (A.types snapshot)
                | answer label=case fields (#" ",label) of
                    [what,ordinal] =>
                      let val ordinal=valOf (Int.fromString ordinal)
                      in case (unitOf ordinal,what) of
                           (NONE,_) => ["not reached"]
                         | (SOME unit,"occurrences") => unit::List.map occurrenceText (A.occurrencesIn (snapshot,unit))
                         | (SOME unit,"loose") => unit::List.map looseText (A.occurrencesIn (snapshot,unit))
                         | (SOME unit,_) => unit::List.map factText (A.factsIn (snapshot,unit)) end
                  | _ => raise Fail ("not a label: " ^ label)
          in List.map (fn label => (label,answer label)) labels end
        fun labelsFor (inputs:A.input list,edited)=
          let val units=length inputs
              val ordered=Vector.fromList inputs
              val ordinals=List.tabulate (units,fn i => i)
              fun touched ordinal=List.exists (fn file => #file (Vector.sub (ordered,ordinal))=file) edited
              val chosen=if !sample<0 then ordinals else List.filter touched ordinals @ List.tabulate (!sample,fn _ => next units)
          in ["diagnostics","types"] @ List.concat (List.map (fn ordinal =>
               ["occurrences " ^ num ordinal,"loose " ^ num ordinal,"facts " ^ num ordinal]) chosen) end
        fun freshOf edited=
          let val other=A.create (compiler,{context="fresh"})
              val ()=A.store (other,NONE)
              val ()=if !focusing andalso !againstRecord then A.focus (other,SOME edited) else ()
          in (other,checkIn (other,never)) end
        fun firstDifference (left,right)=
          let fun first ([],[])=() | first (x::_,[])=say ("  kept only: " ^ x ^ "\n") | first ([],y::_)=say ("  fresh only: " ^ y ^ "\n")
                | first (x::xs,y::ys)=if x=y then first (xs,ys) else say ("  kept:  " ^ x ^ "\n  fresh: " ^ y ^ "\n")
          in first (left,right) end
        fun compare (name,rep,kept:A.snapshot,edited:string list)=
          let val labels=labelsFor (A.inputs kept,edited)
              val found=answers (kept,labels)
          in case !recording of
               SOME output =>
                 (TextIO.output (output,"check " ^ name ^ " " ^ num rep ^ "\n");
                  List.app (fn (label,lines) => TextIO.output (output,label ^ "\t" ^ hex (String.concatWith "\n" lines) ^ "\n")) found;
                  TextIO.flushOut output;true)
             | NONE =>
               let val (other,fresh)=freshOf edited
                   val bad=ref 0
                   fun same ((label,left),(_,right))=if left=right then () else
                     if String.isPrefix "loose" label then () else
                     (bad:= !bad+1;disagreements:= !disagreements+1;
                      say ("  " ^ label ^ " differs, " ^ num (length left) ^ " against " ^ num (length right) ^ ":\n");
                      firstDifference (left,right);
                      if String.isPrefix "occurrences" label andalso
                         List.exists (fn (l,looser) => l="loose " ^ String.extract (label,12,NONE) andalso
                           SOME looser=Option.map #2 (List.find (fn (m,_) => m=l) (answers (fresh,[l])))) found
                      then bindingsApart:= !bindingsApart+1 else ())
                   val ()=ListPair.app same (found,answers (fresh,labels))
                   val ()=A.close other
               in if !bad=0 then () else say ("ORACLE " ^ name ^ " " ^ num rep ^ ": " ^ num (!bad) ^ " disagreements\n");!bad=0 end end
        (* against what a run recorded: its next check, by its name *)
        fun recorded (name,rep)=
          let val heading="check " ^ name ^ " " ^ num rep
              fun take ([],kept)=(List.rev kept,[])
                | take (rest as line::others,kept)=if String.isPrefix "check " line then (List.rev kept,rest) else take (others,line::kept)
          in case !expected of
               line::rest => if line<>heading then raise Fail ("the record has " ^ line ^ " where this run has " ^ heading) else
                 let val (lines,after)=take (rest,[]) in expected:=after;lines end
             | [] => raise Fail ("the record ends before " ^ heading) end
        fun against (name,rep,edited)=
          let val lines=recorded (name,rep)
              val pairs=List.map (fn line => case fields (#"\t",line) of [label,digest] => (label,digest) | _ => raise Fail "not a record") lines
              val (other,fresh)=freshOf edited
              val bad=ref 0
              val ()=List.app (fn ((label,digest),(_,answer)) =>
                if hex (String.concatWith "\n" answer)=digest orelse String.isPrefix "loose" label then () else
                  (bad:= !bad+1;disagreements:= !disagreements+1;say ("  " ^ label ^ " differs from the record\n")))
                (ListPair.zip (pairs,answers (fresh,List.map #1 pairs)))
              val ()=A.close other
              val ()=checks:= !checks+1
          in say (name ^ " " ^ num rep ^ ": " ^ (if !bad=0 then "same as the record" else "DIFFERS FROM THE RECORD") ^ "\n");
             emit [("scenario",Json.String name),("rep",Json.int rep),("same",Json.Bool (!bad=0))] end
        fun measured (name,rep,edited,cancelAt)=
          if !againstRecord then (against (name,rep,edited);NONE) else SOME (keptCheck (name,rep,edited,cancelAt))
        and keptCheck (name,rep,edited,cancelAt)=
          let val ()=case cancelAt of NONE => () | SOME n =>
                let val polls=ref 0
                in (ignore (checkIn (context,fn () => (polls:= !polls+1;!polls>=n)));say ("  the cancelled check ended by itself\n"))
                   handle A.Cancelled => (took "cancelled";say ("  cancelled at poll " ^ num n ^ "\n")) end
              val before'=Runtime.stats ()
              val timer=Timer.startRealTimer ()
              val snapshot=checkIn (context,never)
              val seconds=Time.toReal (Timer.checkRealTimer timer)
              val after=Runtime.stats ()
              val {checked,reused}=A.work snapshot
              val {walked,rebound,loaded,cutoff,broken,stored}=A.route snapshot
              val ()=(if walked then took "walked" else took "placed";
                      if !shares andalso name="cold" andalso loaded>0 then took "shared" else ();
                      if rebound>0 then took "rebound" else ();if loaded>0 then took "loaded" else ();
                      if stored>0 then took "stored" else ();
                      if cutoff>0 then took "cutoff" else ();if broken>0 then took "broken" else ();
                      if null (A.diagnostics snapshot) then () else took "failed")
              val ()=checks:= !checks+1
              val agreed=if !fresh then SOME (compare (name,rep,snapshot,edited)) else NONE
              val ()=placeholder:=SOME snapshot
              val live=if !collecting then (Runtime.collect ();Runtime.collect ();#live (Runtime.stats ())) else #live after
          in emit ([("scenario",Json.String name),("rep",Json.int rep),("seconds",Json.Number (Real.toString seconds)),
               ("checked",Json.int checked),("reused",Json.int reused),("walked",Json.Bool walked),("rebound",Json.int rebound),
               ("loaded",Json.int loaded),("cutoff",Json.int cutoff),("broken",Json.int broken),("stored",Json.int stored),
               ("diagnostics",Json.int (length (A.diagnostics snapshot))),("instructions",Json.int (#instructions after- #instructions before')),
               ("allocated",Json.int (#bytes after- #bytes before')),("live",Json.int live)] @
               (case agreed of NONE => [] | SOME same => [("same",Json.Bool same)]));
             say (name ^ " " ^ num rep ^ ": " ^ Real.fmt (StringCvt.FIX (SOME 3)) seconds ^ " s, checked " ^ num checked ^ ", reused " ^ num reused ^
               (if walked then ", walked" else ", placed") ^ ", rebound " ^ num rebound ^ ", loaded " ^ num loaded ^ ", cutoff " ^ num cutoff ^ ", broken " ^ num broken ^
               (if stored>0 then ", stored " ^ num stored else "") ^
               (if !collecting then ", live " ^ Real.fmt (StringCvt.FIX (SOME 1)) (real live/1048576.0) ^ " MiB" else "") ^
               (case A.diagnostics snapshot of [] => "" | d::_ => ", diagnostic: " ^ #file d ^ ":" ^ num (#line d) ^ ": " ^ #message d) ^
               (case agreed of NONE => "" | SOME true => ", same as fresh" | SOME false => ", DIFFERS FROM FRESH") ^ "\n");
             snapshot end
        val _=measured ("cold",0,[],NONE)
        fun fileFor suffix=
          let val all=List.map #file (inputs ())
              val builds=List.map #file (List.filter (fn input:C.Project.input => #kind input="build") (C.Project.inputs (project ())))
              fun last candidates=List.foldl (fn (file,found) => if String.isSuffix suffix file then SOME file else found) NONE candidates
          in if suffix="LAST" then List.last all else if suffix="FIRST" then hd all else
             case last (all @ builds) of SOME file => file | NONE => raise Fail ("no input ends " ^ suffix) end
        fun applied (kind,arguments,original,n)=case (kind,arguments) of
            ("append",_) => original ^ "\n(* edit " ^ num n ^ " *)\n"
          | ("prepend",_) => "(* edit " ^ num n ^ " *)\n" ^ original
          | ("appendtext",[text]) => original ^ "\n" ^ expand (unescape text,n) ^ "\n"
          | ("replace",[old,new]) => substitute (original,unescape old,expand (unescape new,n))
          | ("toggle",[old,new]) => if n mod 2=1 then substitute (original,unescape old,expand (unescape new,n)) else original
          | _ => raise Fail ("not a kind of edit: " ^ kind)
        fun query (name,suffix,text)=
          let val file=fileFor suffix
              val all=inputs ()
              fun ordinal (_,[])=raise Fail "no such input"
                | ordinal (n,(input:A.input)::rest)=if #file input=file then n else ordinal (n+1,rest)
              val at=ordinal (0,all)
              val source= #text (List.nth (all,at))
              val (front,found)=Substring.position text (Substring.full source)
              val ()=if Substring.isEmpty found then raise Fail ("no such text: " ^ text) else ()
              val offset=Substring.size front+size text
              fun asked snapshot=List.map candidateText (A.visibleAt (snapshot,{ordinal=at,offset=offset,path=[]}))
              fun freshly ()=
                let val (other,base)=freshOf [file]
                    val answer=asked base
                in A.close other;answer end
          in if !againstRecord then
               (case recorded (name,1) of
                  [line] => if hex (String.concatWith "\n" (freshly ()))=line then say (name ^ ": same as the record\n") else
                    (disagreements:= !disagreements+1;say ("ORACLE " ^ name ^ ": the query differs from the record\n"))
                | _ => raise Fail "not a record")
             else
               let val timer=Timer.startRealTimer ()
                   val kept=asked (valOf (!placeholder))
                   val seconds=Time.toReal (Timer.checkRealTimer timer)
                   val ()=took "query"
                   val ()=say (name ^ ": a query at input " ^ num at ^ " of " ^ num (length all) ^ ": " ^
                     Real.fmt (StringCvt.FIX (SOME 3)) seconds ^ " s, " ^ num (length kept) ^ " candidates\n")
               in case !recording of
                    SOME output => (TextIO.output (output,"check " ^ name ^ " 1\n" ^ hex (String.concatWith "\n" kept) ^ "\n");TextIO.flushOut output)
                  | NONE => if not (!fresh) then () else
                      if freshly ()=kept then () else
                        (disagreements:= !disagreements+1;say ("ORACLE " ^ name ^ ": the query differs from fresh\n")) end end
        fun scenario ({name,repetitions,edits}:scenario)=
          case edits of
            [{suffix,kind="complete",arguments=[text]}] => query (name,suffix,text)
          | _ =>
            let val cancelAt=case List.find (fn edit:edit => #kind edit="cancel") edits of
                  SOME {arguments=[n],...} => Int.fromString n | _ => NONE
                val edits=List.filter (fn edit:edit => #kind edit<>"cancel") edits
                val created=ref [] : string list ref
                val sites=List.map (fn {suffix,kind,arguments}:edit =>
                  if kind="new" then
                    let val file=OS.Path.concat (OS.Path.dir (fileFor "LAST"),suffix)
                    in created:=file:: !created;(file,"",kind,arguments) end
                  else let val file=fileFor suffix in (file,textOf file,kind,arguments) end) edits
                fun open' ()=if !focusing then A.focus (context,SOME (List.map #1 sites)) else ()
                val ()=open' ()
                fun apply n=List.app (fn (file,original,kind,arguments) =>
                  setOverlay (file,if kind="new" then expand (unescape (hd arguments),n) else applied (kind,arguments,original,n))) sites
                val edited=List.map #1 sites
                fun repeat n=if n>repetitions then () else
                  (apply n;ignore (measured (name,n,edited,if n=1 then cancelAt else NONE));repeat (n+1))
                val ()=repeat 1
                val ()=List.app (fn (file,original,_,_) => if original="" then dropOverlay file else setOverlay (file,original)) sites
                val ()=List.app dropOverlay (!created)
            in ignore (measured (name ^ "-restore",0,edited,NONE)) end
        val ()=List.app scenario (parseScenarios (read (!scenariosFile)))
        val ()=if not (!focusing) orelse !againstRecord orelse List.length (inputs ())<2 then () else
          let val ()=A.focus (context,SOME [])
              val closed=checkIn (context,never)
              val ordinal=length (A.inputs closed) div 2
              val unit=valOf (A.unitAt (closed,{ordinal=ordinal}))
          in if null (A.occurrencesIn (closed,unit)) then () else took "opened" end
        val missing=List.filter (fn path => not (List.exists (fn other => other=path) (!taken))) (!required)
        val unknown=List.filter (fn path => not (List.exists (fn other => other=path) paths)) (!required)
        val ()=A.close context
        val ()=TextIO.closeOut output
        val ()=Option.app TextIO.closeOut (!recording)
        val ()=say ("checks " ^ num (!checks) ^ ", disagreements " ^ num (!disagreements) ^ " (only a definition's place in " ^ num (!bindingsApart) ^
          "), paths taken: " ^ String.concatWith " " (List.rev (!taken)) ^ "\n")
        val ()=if null missing andalso null unknown then () else
          say ("ORACLE a path not taken: " ^ String.concatWith " " (missing @ unknown) ^ "\n")
    in if !disagreements=0 andalso null missing andalso null unknown then OS.Process.success else OS.Process.failure end
    handle Fail message => (print ("rune-lsp-oracle: " ^ message ^ "\n");OS.Process.failure)
         | C.Failed diagnostics => (print ("rune-lsp-oracle: " ^ String.concatWith "\n" (List.map #message diagnostics) ^ "\n");OS.Process.failure)
end
