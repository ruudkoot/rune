(* Posix.Signal: the signals, as the numbers the system gives them. *)
structure RunePosixSignal :>
sig
  (* abstract, as the specification has it; the number goes in and out
     through fromInt and toInt, which only the library names *)
  eqtype signal
  val toWord : signal -> Word.word
  val fromWord : Word.word -> signal
  val abrt : signal  val alrm : signal  val bus : signal   val chld : signal
  val cont : signal  val fpe : signal   val hup : signal   val ill : signal
  val int : signal   val kill : signal  val pipe : signal  val quit : signal
  val segv : signal  val stop : signal  val term : signal  val tstp : signal
  val ttin : signal  val ttou : signal  val usr1 : signal  val usr2 : signal
  val toInt : signal -> int
  val fromInt : int -> signal
end =
struct
  type signal = int
  fun toInt (s : signal) = s
  fun fromInt (s : int) : signal = s

  local
    val const = _prim "posix_const" : string -> int
    fun named name = case const name of ~1 => 0 | v => v
  in
    fun toWord (s : signal) = Word.fromInt s
    fun fromWord w = Word.toInt w

    val abrt = named "SIGABRT"   val alrm = named "SIGALRM"
    val bus = named "SIGBUS"     val chld = named "SIGCHLD"
    val cont = named "SIGCONT"   val fpe = named "SIGFPE"
    val hup = named "SIGHUP"     val ill = named "SIGILL"
    val int = named "SIGINT"     val kill = named "SIGKILL"
    val pipe = named "SIGPIPE"   val quit = named "SIGQUIT"
    val segv = named "SIGSEGV"   val stop = named "SIGSTOP"
    val term = named "SIGTERM"   val tstp = named "SIGTSTP"
    val ttin = named "SIGTTIN"   val ttou = named "SIGTTOU"
    val usr1 = named "SIGUSR1"   val usr2 = named "SIGUSR2"
  end
end
