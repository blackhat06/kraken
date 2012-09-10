{
  open Common
  open Spec
  open Parse

  let chop_quotes s =
    String.sub s 1 (String.length s - 2)
}

let num = "0" | ['1'-'9']['0'-'9']*
let str = '"'[^'"''\n']*'"'
let id = ['a'-'z''A'-'Z']['a'-'z''A'-'Z''0'-'9']*
let comment = "#"[^'\n']*
let space = [' ' '\t']
let line = '\n'

rule token = parse
  | "Messages" { MESSAGES }
  | "Protocol" { PROTOCOL }
  | "num" { NUM }
  | "str" { STR }
  | "fdesc" { FDESC }
  | "call" { CALL }
  | ">>" { SENDS }
  | "<<" { RECVS }
  | "=" { EQ }
  | "{" { LCURL }
  | "}" { RCURL }
  | "(" { LPAREN }
  | ")" { RPAREN }
  | "," { COMMA }
  | ";" { SEMI }
  | eof { EOF }
  | num as x { NUMLIT (int_of_string x) }
  | str as x { STRLIT (chop_quotes x) }
  | id as x { ID x }
(* ignore *)
  | comment { token lexbuf }
  | space { token lexbuf }
  | line { incr line; token lexbuf }
(* error *)
  | _ as c { failwith (mkstr "Lex: bogus char '%c' on line %d" c !line) }
