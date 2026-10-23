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
  datatype 'a t=Jobs of {command:string,args:string list,timeout:Time.time,cancelGrace:Time.time,maxPending:int,
    worker:P.t option ref,retired:P.t list ref,phase:phase ref,queue:'a job list ref,active:'a job option ref,
    serial:IntInf.int ref,events:'a event list ref,closed:bool ref}
  exception Full
  fun new {command,args,timeout,cancelGrace,maxPending} =
    if maxPending<1 then raise Domain else Jobs {command=command,args=args,timeout=timeout,cancelGrace=cancelGrace,
      maxPending=maxPending,worker=ref NONE,retired=ref [],phase=ref Idle,queue=ref [],active=ref NONE,
      serial=ref 0,events=ref [],closed=ref false}
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
    (case !active of NONE => (case (!phase,!queue) of (Starting _,job::rest) =>
         (queue:=rest;emit (jobs,Failed (#data job,message))) | _ => ()) | SOME job =>
       (case !phase of Cancelling _ => () | _ => emit (jobs,Failed (#data job,message)));
     active:=NONE;retire jobs;phase:=Idle;emit (jobs,Restarted))
  fun startNext (jobs as Jobs {worker,command,args,queue,active,phase,timeout,closed,...}) =
    if !closed orelse null (!queue) then () else
      case !worker of NONE =>
        let val ()=phase:=Starting (Time.+ (Time.now (),Time.fromSeconds 30))
            val process=P.start {command=command,args=args,
              limits={addressSpace=SOME (768*1024*1024),cpuTime=NONE,fileSize=NONE,core=SOME 0}}
        in worker:=SOME process end
      | SOME process => case (!phase,!queue) of (Idle,job::rest) =>
          (queue:=rest;active:=SOME job;phase:=Working (Time.+ (Time.now (),timeout));P.enqueue (process,#payload job))
        | _ => ()
  fun message (jobs as Jobs {active,phase,...},value) =
    let val ready=(V.bytes (V.field (value,"op"))="ready") handle V.Invalid _ => false
    in if ready then
         (case !active of NONE => phase:=Idle | SOME _ => lost (jobs,"analysis worker became ready before replying"))
       else let val id=V.integer (V.field (value,"id"))
       in case !active of NONE => lost (jobs,"analysis worker replied without an active job")
        | SOME job => if #id job<>id then lost (jobs,"analysis worker replied with a different job id") else
          let val cancelling=case !phase of Cancelling _ => true | _ => false
              val fields=V.object value
              fun optional name=case List.find (fn (key,_) => key=name) fields of NONE => NONE | SOME (_,value) => SOME value
              val ()=if cancelling then () else case optional "result" of SOME result => emit (jobs,Done (#data job,result))
                | NONE => (case optional "cancelled" of SOME (V.Bool true) => emit (jobs,Cancelled (#data job))
                  | _ => (case optional "error" of SOME (error as V.Object _) =>
                      emit (jobs,Rejected (#data job,{code=V.integer (V.field (error,"code")),
                        message=V.bytes (V.field (error,"message")),
                        data=case List.find (fn (name,_) => name="data") (V.object error) of NONE => NONE | SOME (_,value) => SOME value}))
                    | SOME message => emit (jobs,Failed (#data job,V.bytes message))
                    | NONE => emit (jobs,Failed (#data job,"invalid worker response"))))
          in active:=NONE;phase:=AwaitReady end
       end end
    handle V.Invalid message => lost (jobs,message)
  fun tick (jobs as Jobs {retired,phase,...}) =
    let val ()=retired:=List.filter (fn process => (not (isSome (P.reap process))) handle OS.SysErr _ => false) (!retired)
        val expired=case !phase of Starting deadline => Time.> (Time.now (),deadline)
          | Working deadline => Time.> (Time.now (),deadline) | Cancelling deadline => Time.> (Time.now (),deadline) | _ => false
        val ()=if expired then lost (jobs,"analysis worker exceeded its deadline") else ()
    in startNext jobs end
    handle error => lost (jobs,General.exnMessage error)
  fun descriptors (Jobs {worker,...})=case !worker of NONE => [] | SOME process => P.descriptors process
  fun pump (jobs as Jobs {worker,events,...},ready) =
    let val ()=case !worker of NONE => () | SOME process => List.app
          (fn P.Message value => message (jobs,value) | P.Ended => lost (jobs,"analysis worker exited")
            | P.Failed message => lost (jobs,message)) (P.pump (process,ready))
        val ()=tick jobs
        val result=List.rev (!events)
    in events:=[];result end
  fun close (jobs as Jobs {queue,active,closed,...}) =
    (closed:=true;queue:=[];active:=NONE;retire jobs)
end
