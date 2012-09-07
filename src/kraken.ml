open Common

let usage () =
  print "
Usage: kraken [options] input.krn

Compile a Kraken kernel spec to Coq code and proofs and additionally produce
client libraries. Not intended to be run directly, should be invoked by
kraken.sh driver script.

!!! NOTE !!!

  The fact you are reading this probably means you hit a bug in the kraken.sh
  driver script. This usage information is for the core compiler which should
  only be run directly for development and debugging. In particular, this is NOT
  the usage information for the kraken.sh driver script. Hope that helps.

OPTIONS:
  -h, --help        print this usage information
  --turn TURN       write Coq Turn module to file TURN
  --lib LIB         write client libraries to directory LIB
";
  exit 1

let flags : (string * string) list ref =
  ref []

let set_flag f v =
  flags := (f, v) :: !flags

let get_flag f =
  try
    List.assoc f !flags
  with Not_found ->
    failwith (mkstr "Flag '%s' not set." f)

let parse_args () =
  let rec loop = function
    | "-h" :: t | "-help" :: t | "--help" :: t ->
        usage ()
    | "--turn" :: f :: t ->
        set_flag "turn" f;
        loop t
    | "--lib" :: f :: t ->
        set_flag "lib" f;
        loop t
    | i :: t ->
        if Filename.check_suffix i ".krn" then begin
          set_flag "input" i;
          loop t
        end else begin
          print "Unrecognized option '%s'\n" i;
          usage()
        end
    | [] ->
        ()
  in
  let args =
    (* drop executable name *)
    List.tl (Array.to_list Sys.argv)
  in
  if args = [] then
    usage ()
  else
    loop args

let parse_spec f =
  f |> readfile
    |> Lexing.from_string
    |> Parse.spec Lex.token

let lib_path f =
  Filename.concat (get_flag "lib") f

let main () =
  parse_args ();
  let s =
    parse_spec (get_flag "input")
  in
  List.iter (uncurry writefile)
    [ get_flag "turn"   , Gen.turn s
    ; lib_path "msg.c"  , Gen.clib s
    ; lib_path "msg.py" , Gen.pylib s
    ]

let _ =
  main ()
