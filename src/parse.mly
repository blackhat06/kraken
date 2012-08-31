%{
  open Common
  open Spec

  let parse_error s =
    failwith (mkstr "Parse: error on line %d" !line)
%}

%token MESSAGES PROTOCOL NUM STR
%token SENDS RECVS LCURL RCURL LPAREN RPAREN
%token COMMA SEMI EOF

%token <int> NLIT
%token <string> SLIT
%token <string> ID

%start spec
%type <Spec.spec> spec

%%

spec :
  | MESSAGES LCURL msg_decls RCURL 
    PROTOCOL LCURL handlers RCURL
    EOF
    { spec $3 $7 }
;;

handlers :
  | handler
    { $1 :: [] }
  | handler handlers
    { $1 :: $2 }
;;

handler :
  | ID SENDS msg_pat
    LCURL prog RCURL
    { handler ($1, $3) $5 }
;;

prog :
  | cmd
    { $1 }
  | cmd prog
    { Seq ($1, $2) }
;;

cmd :
  | ID RECVS msg_expr SEMI
    { Send ($1, $3) }
;;

msg_expr :
  | ID LPAREN RPAREN
    { msg $1 [] }
  | ID LPAREN exprs RPAREN
    { msg $1 $3 }
;;

exprs :
  | expr
    { $1 :: [] }
  | expr COMMA exprs
    { $1 :: $3 }
;;

expr :
  | NLIT { NLit $1 }
  | SLIT { SLit $1 }
  | ID { Var $1 }
;;

msg_pat :
  | ID LPAREN RPAREN
    { msg $1 [] }
  | ID LPAREN ids RPAREN
    { msg $1 $3 }
;;

ids :
  | ID
    { $1 :: [] }
  | ID COMMA ids
    { $1 :: $3 }
;;

msg_decls :
  | msg_decl
    { $1 :: [] }
  | msg_decl msg_decls
    { $1 :: $2 }
;;

msg_decl :
  | ID LPAREN RPAREN SEMI
    { msg $1 [] }
  | ID LPAREN typs RPAREN SEMI
    { msg $1 $3 }
;;

typs :
  | typ
    { $1 :: [] }
  | typ COMMA typs
    { $1 :: $3 }
;;

typ :
  | NUM { Num }
  | STR { Str }
;;
