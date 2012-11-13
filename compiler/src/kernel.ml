open Common

type id = string
type chan = string

type typ =
  | Num
  | Str
  | Fdesc
  | Chan

type expr =
  | Var     of id
  | NumLit  of int
  | StrLit  of string
  | Plus    of expr * expr
  | CompFld of id * id
  | FunCall of id * expr list

type when_cond =
  | Always
  | NumEq  of id * int
  | ChanEq of id * id
  | StrEq  of expr * expr

type 'a msg =
  { tag : string
  ; payload : 'a list
  }

let mk_msg t p =
  { tag = t
  ; payload = p
  }

let tag m =
  m.tag

type msg_pat  = id msg
type msg_decl = typ msg
type msg_expr = expr msg

type cmd =
  | Send    of chan * msg_expr
  | Call    of id * expr * expr
  | Spawn   of id * (id * expr list)
  | Connect of id * expr
  | Assign  of id * expr

type prog =
  | Nop
  | Seq of cmd * prog

(* symbolic state
 *
 * Track current value of state var during a handler's symbolic execution.
 * For example, after [a := a + 1], [a] is mapped to [a + 1].
 *)
type sstate = (id * expr) list

(*
  I'm sorry, this is quite hacky :(
  sstate holds the final mapping
*)
type uprog = prog * sstate

type cond_prog =
  { condition : when_cond
  ; program   : uprog
  }

let mk_cond_prog c r =
  { condition = c
  ; program   = r
  }

type handler =
  { trigger  : msg_pat
  ; responds : cond_prog list
  }

let mk_handler t r =
  { trigger  = t
  ; responds = r
  }

type kaction_pat =
  | KAP_Any
  | KAP_KSend of string
  | KAP_KRecv of string

type ktrace_pat =
  | KTP_Emp
  | KTP_Act  of kaction_pat
  | KTP_NAct of kaction_pat
  | KTP_Alt  of ktrace_pat * ktrace_pat
  | KTP_And  of ktrace_pat * ktrace_pat
  | KTP_Cat  of ktrace_pat * ktrace_pat
  | KTP_Star of ktrace_pat

type ktrace_spec =
  | KTS_Pat  of ktrace_pat
  | KTS_NPat of ktrace_pat

type prop =
  | ImmAfter  of string * string
  | ImmBefore of string * string
  | KTracePat of ktrace_spec

type component =
  string

type kernel =
  { constants  : (id * expr) list
  ; var_decls  : (id * typ) list
  ; components : (id * (string * (id * typ) list)) list
  ; msg_decls  : msg_decl list
  ; init       : uprog
  ; exchange   : chan * ((component * handler list) list)
  ; props      : (id * prop) list
  }

let empty_kernel =
  { constants  = []
  ; var_decls  = []
  ; components = []
  ; msg_decls  = []
  ; init       = (Nop, [])
  ; exchange   = ("__xch__", [])
  ; props      = []
  }

let ck_kernel _ =
  (* TODO *)
  (* msg tags start with uppercase *)
  (* msg tags uniq *)
  (* BadTag not in msg tags *)
  (* msg pat triggers have uniq ids *)
  ()

(* generate unique id # for each message tag *)
(* start at 1 so BadTag can always have id 0 *)
let gen_tag_map kernel =
  let tags = List.map tag kernel.msg_decls in
  List.combine tags (range 1 (List.length tags + 1))

(* support lex/parse error reporting *)
let line = ref 1
