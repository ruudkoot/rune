(* Foreground-priority jobs, coalesced background work and bounded cancellation.
   The caller owns LSP request/version policy; this layer owns one worker. *)
structure RuneLspJobs =
struct
  structure V=RuneLspWorkerWire
  structure P=RuneLspWorkerProcess
  type rejection={code:IntInf.int,message:string,data:V.value option}
  datatype 'a event=Done of 'a * V.value | Failed of 'a * string | Rejected of 'a * rejection | Cancelled of 'a | Restarted
  type 'a job={id:IntInf.int,key:string option,priority:int,data:'a,payload:V.value}
  datatype phase=Starting of Time.time | Idle | Working of Time.time | Cancelling of Time.time | AwaitReady
  type progress={phase:string,file:string,checked:IntInf.int,reused:IntInf.int,at:Time.time}
  datatype 'a t=Jobs of {command:string,args:string list,timeout:Time.time,cancelGrace:Time.time,maxPending:int,
    worker:P.t option ref,retired:P.t list ref,phase:phase ref,queue:'a job list ref,active:'a job option ref,
    serial:IntInf.int ref,events:'a event list ref,closed:bool ref,started:Time.time option ref,
    progress:progress option ref,context:(string*string) option ref}
  exception Full
  fun new {command,args,timeout,cancelGrace,maxPending} =
    if maxPending<1 then raise Domain else Jobs {command=command,args=args,timeout=timeout,cancelGrace=cancelGrace,
      maxPending=maxPending,worker=ref NONE,retired=ref [],phase=ref Idle,queue=ref [],active=ref NONE,
      serial=ref 0,events=ref [],closed=ref false,started=ref NONE,progress=ref NONE,context=ref NONE}
  (* Only bounded metadata reaches logs: never the captured source/state. *)
  fun preview text =
    let val text=if size text<=256 then text else String.substring(text,0,96) ^ "..." ^ String.extract(text,size text-160,NONE)
        fun escaped c="\\x" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX(Char.ord c))
        fun loop(i,all)=if i=size text then String.concat(List.rev all) else
          case Utf8.decode(text,i) of SOME(_,count)=>
            if count=1 andalso (Char.ord(String.sub(text,i))<32 orelse String.sub(text,i)=Char.chr 127)
            then loop(i+1,escaped(String.sub(text,i))::all) else loop(i+count,String.substring(text,i,count)::all)
          | NONE=>loop(i+1,escaped(String.sub(text,i))::all)
    in if CharVector.all(fn c=>Char.ord c>=32 andalso Char.ord c<127)text then text else loop(0,[]) end
  fun textField (value,name)=SOME(V.bytes(V.field(value,name))) handle V.Invalid _=>NONE
  fun workspaceJob (job:'a job)=textField(#payload job,"op")=SOME "workspace"
  fun workspaceLimit timeout=Time.fromMicroseconds(IntInf.*(4,Time.toMicroseconds timeout))
  fun elapsed since=Time.toString(if Time.<(Time.now(),since) then Time.zeroTime else Time.-(Time.now(),since)) ^ " s"
  fun details (Jobs{worker,command,active,queue,phase,timeout,cancelGrace,started,progress,context,...}) =
    let val job=case !active of SOME job=>SOME job | NONE=>(case !phase of Starting _=>List.find(fn _=>true)(!queue) | _=>NONE)
        val worker=case !worker of NONE=>"worker PID unavailable"
          | SOME(P.Process{pid,...})=>"worker PID " ^ Int.toString pid
        val limit=case !phase of Starting _=>Time.fromSeconds 30 | Cancelling _=>cancelGrace | _=>timeout
        val timing=(case !started of NONE=>"" | SOME since=>", elapsed " ^ elapsed since) ^
          (case job of SOME job=>if workspaceJob job then ", context limit " else ", limit " | NONE=>", limit ") ^
          Time.toString limit ^ " s"
        fun field(payload,name,label)=case textField(payload,name) of NONE=>"" | SOME ""=>""
          | SOME value=>"\n  " ^ label ^ ": " ^ preview value
        val work=case job of NONE=>"" | SOME job=>", job " ^ IntInf.toString(#id job) ^
          (case textField(#payload job,"op") of NONE=>"" | SOME opName=>" (" ^ preview opName ^ ")") ^
          field(#payload job,"method","request") ^ field(#payload job,"uri","document") ^ field(#payload job,"snapshot","snapshot")
        val selected=case !context of NONE=>"" | SOME(label,build)=>"\n  context: " ^ preview label ^ " (" ^ preview build ^ ")"
        val last=case !progress of NONE=>"\n  last reported phase: none" | SOME update=>"\n  last reported phase: " ^ preview(#phase update) ^
          (if #file update="" then "" else " at " ^ preview(#file update)) ^
          " (checked " ^ IntInf.toString(#checked update) ^ ", reused " ^ IntInf.toString(#reused update) ^
          "; " ^ elapsed(#at update) ^ " before failure)"
    in "\n  " ^ worker ^ timing ^ work ^ "\n  executable: " ^ preview command ^ selected ^ last end
  fun explain(jobs,message)=preview message ^ details jobs
  fun emit (Jobs {events,...},event)=events:=event :: !events
  fun 'a cancel (jobs as Jobs {queue,active,worker,phase,cancelGrace,...},id) =
    let val (removed,kept)=List.partition (fn job:'a job => #id job=id) (!queue)
        val ()=queue:=kept
        val ()=List.app (fn job => emit (jobs,Cancelled (#data job))) removed
    in case !active of SOME job =>
         if #id job<>id then () else (case !phase of Cancelling _ => () | _ =>
           (emit (jobs,Cancelled (#data job));
            Option.app (fn worker => P.enqueue (worker,V.Object [("op",V.Bytes "cancel"),("id",V.Integer id)])) (!worker);
            phase:=Cancelling (Time.+ (Time.now (),cancelGrace))))
       | NONE => () end
  fun 'a submit (jobs as Jobs {queue,active,serial,maxPending,closed,...},{key,priority,data,payload}) =
    if !closed then raise Full else
    let val fields=V.object payload
        val ()=if List.exists (fn (name,_) => name="id") fields then raise V.Invalid "job payload already has an id" else ()
        val ()=Option.app (fn key =>
          (List.app (fn job:'a job => if #key job=SOME key then cancel (jobs,#id job) else ()) (!queue);
           case !active of SOME job => if #key job=SOME key then cancel (jobs,#id job) else () | NONE => ())) key
        val ()=if length (!queue)+(if isSome (!active) then 1 else 0)>=maxPending then raise Full else ()
        val id= !serial
        val ()=serial:=IntInf.+ (id,1)
        val job={id=id,key=key,priority=priority,data=data,payload=V.Object (("id",V.Integer id)::fields)}:'a job
        fun insert []=[job] | insert (first::rest)=if priority< #priority first then job::first::rest else first::insert rest
    in queue:=insert (!queue);id end
  fun retire (Jobs {worker,retired,...}) = case !worker of NONE => () | SOME process =>
    (P.terminate process;retired:=process :: !retired;worker:=NONE)
  fun lost (jobs as Jobs {active,phase,queue,...},message) =
    let val message=explain(jobs,message)
    in (case !active of NONE => (case (!phase,!queue) of (Starting _,job::rest) =>
         (queue:=rest;emit (jobs,Failed (#data job,message))) | _ => ()) | SOME job =>
       (case !phase of Cancelling _ => () | _ => emit (jobs,Failed (#data job,message)));
     active:=NONE;retire jobs;phase:=Idle;emit (jobs,Restarted)) end
  fun startNext (jobs as Jobs {worker,command,args,queue,active,phase,timeout,closed,started,progress,context,...}) =
    if !closed orelse null (!queue) then () else
      case !worker of NONE =>
        let val ()=(started:=SOME(Time.now());progress:=NONE;context:=NONE;
              phase:=Starting (Time.+ (Time.now (),Time.fromSeconds 30)))
            val process=P.start {command=command,args=args,
              limits={addressSpace=SOME (1536*1024*1024),cpuTime=NONE,fileSize=NONE,core=SOME 0}}
        in worker:=SOME process end
      | SOME process => case (!phase,!queue) of (Idle,job::rest) =>
          (queue:=rest;active:=SOME job;started:=SOME(Time.now());progress:=NONE;context:=NONE;
           phase:=Working (Time.+ (Time.now (),timeout));P.enqueue (process,#payload job))
        | _ => ()
  fun message (jobs as Jobs {active,phase,progress,context,started,timeout,...},value) =
    let val opName=textField(value,"op")
        val ready=opName=SOME "ready"
    in if ready then
         (case !active of NONE => (phase:=Idle;progress:=NONE;context:=NONE;started:=NONE)
          | SOME _ => lost (jobs,"analysis worker became ready before replying"))
       else let val id=V.integer (V.field (value,"id"))
       in case !active of NONE => lost (jobs,"analysis worker replied without an active job")
        | SOME job => if #id job<>id then lost (jobs,"analysis worker replied with a different job id") else
          if opName=SOME "progress" then
            let val name=V.bytes(V.field(value,"phase")) val file=preview(V.bytes(V.field(value,"file")))
                fun count key=let val n=(V.integer(V.field(value,key)) handle V.Invalid _=>0)
                  in if IntInf.<(n,0) orelse IntInf.>(n,1000000) then raise V.Invalid "invalid worker progress count" else n end
                val ()=if size name>256 then raise V.Invalid "worker progress metadata exceeds limit" else ()
                val ()=case textField(value,"context") of NONE=>() | SOME label=>context:=SOME(preview label,file)
                (* A workspace sweep checks several independent projects.
                   Unit progress cannot extend a stalled project's deadline. *)
                val ()=case !phase of Working _=>
                  if workspaceJob job andalso name="project-selected" then
                    phase:=Working(Time.+(Time.now(),timeout)) else () | _=>()
            in progress:=SOME{phase=name,file=file,checked=count "checked",reused=count "reused",at=Time.now()} end
          else
          let val cancelling=case !phase of Cancelling _ => true | _ => false
              val fields=V.object value
              fun optional name=case List.find (fn (key,_) => key=name) fields of NONE => NONE | SOME (_,value) => SOME value
              val ()=if cancelling then () else case optional "result" of SOME result => emit (jobs,Done (#data job,result))
                | NONE => (case optional "cancelled" of SOME (V.Bool true) => emit (jobs,Cancelled (#data job))
                  | _ => (case optional "error" of SOME (error as V.Object _) =>
                      emit (jobs,Rejected (#data job,{code=V.integer (V.field (error,"code")),
                        message=V.bytes (V.field (error,"message")),
                        data=case List.find (fn (name,_) => name="data") (V.object error) of NONE => NONE | SOME (_,value) => SOME value}))
                    | SOME message => emit (jobs,Failed (#data job,explain(jobs,V.bytes message)))
                    | NONE => emit (jobs,Failed (#data job,explain(jobs,"invalid worker response")))))
          in active:=NONE;phase:=AwaitReady end
       end end
    handle V.Invalid message => lost (jobs,message)
  fun tick (jobs as Jobs {retired,phase,active,started,timeout,...}) =
    let val ()=retired:=List.filter (fn process => (not (isSome (P.reap process))) handle OS.SysErr _ => false) (!retired)
        val expired=case !phase of Starting deadline => Time.> (Time.now (),deadline)
          | Working deadline => Time.> (Time.now (),deadline) | Cancelling deadline => Time.> (Time.now (),deadline) | _ => false
        val workspaceExpired=case (!phase,!active,!started) of (Working _,SOME job,SOME since)=>
          workspaceJob job andalso Time.>(Time.now(),Time.+(since,workspaceLimit timeout)) | _=>false
        val ()=if workspaceExpired then lost(jobs,"analysis worker exceeded its overall workspace deadline (" ^
            Time.toString(workspaceLimit timeout) ^ " s)")
          else if expired then lost (jobs,"analysis worker exceeded its deadline") else ()
    in startNext jobs end
    handle error => lost (jobs,case error of OS.SysErr(message,code)=>message ^
      (case code of NONE=>"" | SOME code=>": " ^ OS.errorMsg code) | Fail message=>message | _=>General.exnMessage error)
  fun descriptors (Jobs {worker,...})=case !worker of NONE => [] | SOME process => P.descriptors process
  fun pump (jobs as Jobs {worker,events,...},ready) =
    let val ()=case !worker of NONE => () | SOME process => List.app
          (fn P.Message value => message (jobs,value) | P.Ended => lost (jobs,"analysis worker exited")
            | P.Failed message => lost (jobs,message)) (P.pump (process,ready))
        val ()=tick jobs
        val result=List.rev (!events)
    in events:=[];result end
  fun close (jobs as Jobs {queue,active,closed,retired,...}) =
    (closed:=true;queue:=[];active:=NONE;retire jobs;
     List.app(fn process=>ignore(P.await process) handle OS.SysErr _=>())(!retired);retired:=[])
end
