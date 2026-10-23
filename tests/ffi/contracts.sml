(* A finite independent state model for the common Win32 message contract.
   This is a test oracle, not an implementation of the binding library. *)
structure FfiContractTests =
struct
  exception Failed of string
  fun check (name, condition) = if condition then () else raise Failed name
  datatype phase = Registered | Creating | Live | Painting | Destroying | Dead
  datatype event = NcCreate | Create | BeginPaint | EndPaint | Send | NestedSend | Posted | Tick | Destroy | NcDestroy
  val phase = ref Registered
  val trace = ref [] : event list ref
  fun event message = trace := message :: !trace
  fun creation procedure =
    (check ("class registered", !phase = Registered); phase := Creating;
     event NcCreate; procedure NcCreate; event Create; procedure Create;
     check ("callback cannot finish creation", !phase = Creating); phase := Live)
  fun withPaint work =
    let val () = check ("paint requires live window", !phase = Live)
        val () = (phase := Painting; event BeginPaint)
        fun finish () = (event EndPaint; phase := Live)
    in (work () before finish ()) handle e => (finish (); raise e) end
  fun nested () =
    (check ("nested send requires live window", !phase = Live); event Send; event NestedSend; 42)
  val queue = ref ([] : event list)
  fun post message = queue := !queue @ [message]
  fun dispatch () = case !queue of [] => () | message :: rest => (queue := rest; event message)
  val timer = ref false
  fun tick () = if !timer then post Tick else ()
  datatype object = Stock | Owned of {selected : bool ref, live : bool ref}
  val selected = ref Stock
  fun select next =
    let val previous = !selected
        fun mark Stock _ = () | mark (Owned {selected, ...}) value = selected := value
    in mark previous false; mark next true; selected := next; previous end
  fun delete Stock = raise Failed "stock object is borrowed"
    | delete (Owned {selected, live}) =
        (check ("delete requires live unselected object", !live andalso not (!selected)); live := false)
  fun destroy () =
    (check ("destroy requires live window", !phase = Live); phase := Destroying;
     event Destroy; event NcDestroy; phase := Dead)
  val () = creation (fn _ => check ("creation callback is synchronous", !phase = Creating))
  val () = withPaint (fn () => check ("paint lease is live", !phase = Painting))
  val caught = ((withPaint (fn () => raise Fail "paint"); false) handle Fail "paint" => true)
  val () = check ("paint lease closes on exception", caught andalso !phase = Live)
  val () = check ("nested send result", nested () = 42)
  val beforePosting = !trace
  val () = post Posted
  val () = check ("posting is asynchronous", !trace = beforePosting)
  val () = dispatch ()
  val () = timer := true
  val () = tick ()
  val () = dispatch ()
  val () = timer := false
  val () = tick ()
  val () = check ("cancelled timer enqueues no message", null (!queue))
  val owned = Owned {selected = ref false, live = ref true}
  val previous = select owned
  val () = check ("selected object cannot be deleted", ((delete owned; false) handle Failed _ => true))
  val () = ignore (select previous)
  val () = delete owned
  val () = check ("owned object cannot be deleted twice", ((delete owned; false) handle Failed _ => true))
  val () = check ("stock object cannot be deleted", ((delete Stock; false) handle Failed _ => true))
  val () = destroy ()
  val stale = ((ignore (nested ()); false) handle Failed _ => true)
  val () = check ("destroyed window rejects operations", stale)
  val () = check ("message order", List.rev (!trace) =
    [NcCreate, Create, BeginPaint, EndPaint, BeginPaint, EndPaint, Send, NestedSend, Posted, Tick, Destroy, NcDestroy])
  val () = print "PASS ffi/contracts: creation, paint cleanup, messages, timers, objects, destruction\n"
end
