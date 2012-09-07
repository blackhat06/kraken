open Common
open Spec

(*
 * COQ TURN MODULE
 *)

let msg_decl_coq mds =
  let fmt md =
    let args =
      let aux arg acc =
        match arg with
        | Num, _ -> "num -> " ^ acc
        | Str, _ -> "str -> " ^ acc
      in
      List.fold_right aux md.payload "msg"
    in
    mkstr "| %s : %s" md.tag args
  in
  mds
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Inductive msg : Set :=
%s
(* special case for errors *)
| BadTag : num -> msg.
"

let recv_msg_spec_coq tag_map mds =
  let fmt md =
    let hdr =
      mkstr "    | %s %s =>" md.tag
        (md.payload
          |> List.map snd
          |> String.concat " ")
    in
    let recv_pay =
      let aux = function
        | Num, p -> mkstr "      RecvNum c %s ++" p
        | Str, p -> mkstr "      RecvStr c %s ++" p
      in
      md.payload
        |> List.rev
        |> List.map aux
        |> String.concat "\n"
    in
    let recv_tag =
      mkstr "      RecvNum c %s"
        (List.assoc md.tag tag_map)
    in
    mkstr "%s\n%s\n%s"
      hdr recv_pay recv_tag
  in
  mds
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Definition RecvMsg (c : chan) (m : msg) : Trace :=
  match m with
%s
    (* special case for errors *)
    | BadTag p0 =>
      RecvNum c p0
  end.
"

(* WARNING : partial copy/paste of recv_msg_spec_coq *)
let send_msg_spec_coq tag_map mds =
  let fmt md =
    let hdr =
      mkstr "    | %s %s =>" md.tag
        (md.payload
          |> List.map snd
          |> String.concat " ")
    in
    let recv_pay =
      let aux = function
        | Num, p -> mkstr "      SendNum c %s ++" p
        | Str, p -> mkstr "      SendStr c %s ++" p
      in
      md.payload
        |> List.rev
        |> List.map aux
        |> String.concat "\n"
    in
    let recv_tag =
      mkstr "      SendNum c %s"
        (List.assoc md.tag tag_map)
    in
    mkstr "%s\n%s\n%s"
      hdr recv_pay recv_tag
  in
  mds
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Definition SendMsg (c : chan) (m : msg) : Trace :=
  match m with
%s
    (* special case for errors *)
    | BadTag p0 =>
      SendNum c (Num (Ascii false false false false false false false false))
  end.
"

let recv_msg_coq tag_map mds =
  let fmt md =
    let hdr =
        mkstr "      | %s => (* %s *)"
          (List.assoc md.tag tag_map) md.tag
    in
    let recv_pay =
      let recv_typ = function
        | Num -> "recvNum"
        | Str -> "recvStr"
      in
      let recv_typ_trace = function
        | Num -> "RecvNum"
        | Str -> "RecvStr"
      in
      let aux (acc, tr) (t, p) =
        ((mkstr "        %s <- %s c\n" p (recv_typ t) ^
          mkstr "          (tr ~~~ %s);" tr) :: acc
        , mkstr "%s c %s ++ %s" (recv_typ_trace t) p tr
        )
      in
      let tr =
        mkstr "RecvNum c %s ++ tr"
          (List.assoc md.tag tag_map)
      in
       md.payload
        |> List.fold_left aux ([], tr)
        |> fst
        |> List.rev
        |> String.concat "\n"
    in
    let ret =
      mkstr "        {{ Return (%s %s) }}" md.tag
        (md.payload
          |> List.map snd
          |> String.concat " ")
    in
    mkstr "%s\n%s\n%s"
      hdr recv_pay ret
  in
  mds
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Definition recvMsg :
  forall (c : chan) (tr : [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (m : msg) => tr ~~ traced (RecvMsg c m ++ tr) * bound c).
Proof.
  intros; refine (
    tag <- recvNum c
      tr;
    match tag with
%s
      (* special case for errors *)
      | m =>
        {{ Return (BadTag m) }}
    end
  );
  sep fail auto;
    repeat rewrite app_ass; simpl;
    sep fail auto.
Qed.
"

(* WARNING : partial copy/paste of recv_msg_coq *)
let send_msg_coq tag_map mds =
  let fmt md =
    let hdr =
      mkstr "      | %s %s =>\n" md.tag
        (md.payload
          |> List.map snd
          |> String.concat " ") ^
      mkstr "        sendNum c %s\n"
        (List.assoc md.tag tag_map) ^
      mkstr "          tr;;"
    in
    let send_pay =
      let send_typ = function
        | Num -> "sendNum"
        | Str -> "sendStr"
      in
      let send_typ_trace = function
        | Num -> "SendNum"
        | Str -> "SendStr"
      in
      let aux (acc, tr) (t, p) =
        ((mkstr "        %s c %s\n" (send_typ t) p ^
          mkstr "          (tr ~~~ %s);;" tr) :: acc
        , mkstr "%s c %s ++ %s" (send_typ_trace t) p tr
        )
      in
      let tr =
        mkstr "SendNum c %s ++ tr"
          (List.assoc md.tag tag_map)
      in
       md.payload
        |> List.fold_left aux ([], tr)
        |> fst
        |> List.rev
        |> String.concat "\n"
    in
    let ret =
      "        {{ Return tt }}"
    in
    mkstr "%s\n%s\n%s"
      hdr send_pay ret
  in
  mds
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Definition sendMsg :
  forall (c : chan) (m : msg) (tr : [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_ : unit) => tr ~~ traced (SendMsg c m ++ tr) * bound c).
Proof.
  intros; refine (
    match m with
%s
      (* special case for errors *)
      | BadTag _ =>
        sendNum c (Num (Ascii false false false false false false false false))
          tr;;
        {{ Return tt }}
    end
  );
  sep fail auto;
    repeat rewrite app_ass; simpl;
    sep fail auto.
Qed.
"

let protocol_coq hands =
  let fmt hand =
    let pat =
      let p = snd hand.trigger in
      mkstr "  | %s %s =>" (p.tag)
        (String.concat " " p.payload)
    in
    let body =
      let rec sends = function
        | Send (_, m) -> [m]
        | Seq (p1, p2) -> sends p1 @ sends p2
      in
      let rec expr_coq = function
        | NumLit n ->
            mkstr "%d" n
        | StrLit s ->
            (* chop quote chars w/ range from 1 to length - 1 *)
            List.fold_right
              (fun i acc -> mkstr "\"%c\" :: %s" s.[i] acc)
              (range 1 (String.length s - 1))
              "nil"
        | Var id ->
            id
      in
      let aux m =
        mkstr "    %s %s ::" m.tag
          (m.payload
            |> List.map expr_coq
            |> String.concat ") ("
            |> mkstr "(%s)")
      in
      hand.respond
        |> sends
        |> List.map aux
        |> String.concat "\n"
        |> mkstr "%s\n    nil"
    in
    mkstr "%s\n%s" pat body
  in
  hands
    |> List.map fmt
    |> String.concat "\n"
    |> mkstr "
Definition protocol (m : msg) : list msg :=
  match m with
%s
  | _ =>
    nil
  end%%char.
"

let includes_coq = "
Require Import List.
Require Import Ascii.
Require Import Ynot.
Require Import KrakenBase.

Open Local Scope hprop_scope.
Open Local Scope stsepi_scope.
"

let send_msgs_coq = "
Fixpoint SendMsgs (c : chan) (ms : list msg) : Trace :=
  match ms with
    | nil =>
      nil
    | m :: ms' =>
      SendMsgs c ms' ++ SendMsg c m
  end.

Definition sendMsgs :
  forall (c : chan) (ms : list msg) (tr : [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_ : unit) => tr ~~ traced (SendMsgs c ms ++ tr) * bound c).
Proof.
  intros; refine (
    Fix2
      (fun ms tr => tr ~~ traced tr * bound c)
      (fun ms tr (_ : unit) => tr ~~ traced (SendMsgs c ms ++ tr) * bound c)
      (fun self ms tr =>
        match ms with
          | m :: ms' =>
            sendMsg c m
              tr;;
            self ms'
              (tr ~~~ SendMsg c m ++ tr);;
            {{ Return tt }}
          | nil =>
            {{ Return tt }}
        end)
      ms tr
  );
  sep fail auto;
    repeat rewrite app_ass; simpl;
    sep fail auto.
Qed.
"

let turn_coq = "
Definition turn :
  forall (c : chan) (tr : [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (req : msg) => tr ~~ traced (SendMsgs c (protocol req) ++ RecvMsg c req ++ tr) * bound c).
Proof.
  intros; refine (
    req <- recvMsg c
      tr;
    sendMsgs c (protocol req)
      (tr ~~~ RecvMsg c req ++ tr);;
    {{ Return req }}
  );
  sep fail auto.
Qed.
"

let num_of_int i =
  if 0 < i && i < 256 then
    i |> last_bits 8
      |> List.rev
      |> List.map string_of_bool
      |> String.concat " "
      |> mkstr "(Num (Ascii %s))"
  else
    failwith "num_of_int"

let turn s =
  (* generate id number for each message tag *)
  (* start at 1 so BadTag can always have id 0 *)
  let tag_map =
    let tags = List.map tag s.msg_decl in
    let ids = range 1 (List.length tags + 1) in
    List.combine tags (List.map num_of_int ids)
  in
  (* name each param in a msg_decl *)
  let name_params md =
    let nms =
      List.map (mkstr "p%d")
        (range 0 (List.length md.payload))
    in
    msg md.tag (List.combine md.payload nms)
  in
  let mds =
    List.map name_params s.msg_decl
  in
  mkstr "%s%s%s%s%s%s%s%s%s"
    includes_coq
    (msg_decl_coq mds)
    (recv_msg_spec_coq tag_map mds)
    (send_msg_spec_coq tag_map mds)
    (recv_msg_coq tag_map mds)
    (send_msg_coq tag_map mds)
    send_msgs_coq
    (protocol_coq s.protocol)
    turn_coq

(*
 * C MESSAGING LIBRARY
 *)


let clib s =
  ""

(*
 * PYTHON MESSAGING LIBRARY
 *)

let recv_send_pylib = "
import socket, struct

def recvNum(c):
  s = c.recv(1)
  n = struct.unpack('>B', s)[0]
  print '<< %d' % n
  return n

def recvStr(c):
  n = recvNum(c)
  s = c.recv(n)
  print '<< \"%s\"' % s
  return s

def sendNum(c, n):
  s = struct.pack('>B', n)
  c.send(s)
  print '>> %d' % n

def sendStr(c, s):
  sendNum(c, len(s))
  c.send(s)
  print '>> \"%s\"' % s

class Msg:
  def __init__(self, tag, params):
    self.tag = tag
    self.params = params
"

let recv_msg_pylib tag_map mds =
  let fmt md =
    let recv_arg = function
      | Num -> "recvNum(c)"
      | Str -> "recvStr(c)"
    in
    mkstr "%2d : lambda x : Msg('%s', [%s])"
      (List.assoc md.tag tag_map) md.tag
      (md.payload
        |> List.map recv_arg
        |> String.concat ", ")
  in
  mds
    |> List.map fmt
    |> String.concat "\n        , "
    |> mkstr "
def recvMsg(c):
  tag = recvNum(c)
  msg = { %s
        }[tag](0)
  return msg
"

(* WARNING partial copy/past of recv_msg_pylib *)
let send_msg_pylib tag_map mds =
  let fmt md =
    let send_arg i = function
      | Num -> mkstr "sendNum(c, m.params[%d])" i
      | Str -> mkstr "sendStr(c, m.params[%d])" i
    in
    mkstr "'%s' : lambda x : [sendNum(c, %d), %s])"
      md.tag (List.assoc md.tag tag_map)
      (md.payload
        |> List.mapi send_arg
        |> String.concat ", ")
  in
  mds
    |> List.map fmt
    |> String.concat "\n  , "
    |> mkstr "
def sendMsg(c, m):
  { %s
  }[m.tag](0)
"

let pylib s =
  (* WARNING partial copy/paste from spec_coq *)
  let tag_map =
    let tags = List.map tag s.msg_decl in
    List.combine tags (range 1 (List.length tags + 1))
  in
  mkstr "%s%s%s"
    recv_send_pylib
    (recv_msg_pylib tag_map s.msg_decl)
    (send_msg_pylib tag_map s.msg_decl)
