Require Import List.
Require Import Ascii.
Require Import BinNat.
Require Import Nnat.
Require Import Ynot.

Open Local Scope stsepi_scope.
Open Local Scope hprop_scope.

Ltac inv H :=
  inversion H; clear H; subst.

(*
   IO
*)

Definition str : Set :=
  list ascii.

Definition len (s: str) : N :=
  N_of_nat (length s).

Axiom chan : Set.

Inductive Action : Set :=
| RecvN : chan -> N -> Action
| RecvS : chan -> N -> str -> Action
| SendN : chan -> N -> Action
| SendS : chan -> str -> Action.

Definition Trace : Set :=
  list Action.

Definition RecvNum (c: chan) (n: N) : Trace :=
  RecvN c n ::
  nil.

Definition SendNum (c: chan) (n: N) : Trace :=
  SendN c n ::
  nil.

Definition RecvStr (c: chan) (s: str) : Trace :=
  RecvS c (len s) s ::
  RecvN c (len s) ::
  nil.

Definition SendStr (c: chan) (s: str) : Trace :=
  SendS c s ::
  SendN c (len s) ::
  nil.

Axiom bound : chan -> hprop.
Axiom traced : Trace -> hprop.

Axiom recvN:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun n => tr ~~ traced (RecvN c n :: tr) * bound c).

Axiom recvS:
  forall (c: chan) (n: N) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun s => tr ~~ traced (RecvS c n s :: tr) * bound c * [n = len s]).

Axiom sendN:
  forall (c: chan) (n: N) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendN c n :: tr) * bound c).

Axiom sendS:
  forall (c: chan) (s: str) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendS c s :: tr) * bound c).

Definition recvNum:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun n => tr ~~ traced (RecvNum c n ++ tr) * bound c).
Proof.
  intros; refine (
    n <- recvN c
      tr;
    {{ Return n }}
  );
  sep fail auto.  
Qed.

Definition sendNum:
  forall (c: chan) (n: N) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendNum c n ++ tr) * bound c).
Proof.
  intros; refine (
    sendN c n
      tr;;
    {{ Return tt }}
  );
  sep fail auto.  
Qed.

Definition recvStr:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun s => tr ~~ traced (RecvStr c s ++ tr) * bound c).
Proof.
  intros; refine (
    n <- recvN c
      tr;
    s <- recvS c n
      (tr ~~~ RecvN c n :: tr);
    {{ Return s }}
  );
  sep fail auto.  
Qed.

Definition sendStr:
  forall (c: chan) (s: str) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendStr c s ++ tr) * bound c).
Proof.
  intros; refine (
    sendN c (len s)
      tr;;
    sendS c s
      (tr ~~~ SendN c (len s) :: tr);;
    {{ Return tt }}
  );
  sep fail auto.  
Qed.

(*
   MESSAGES
*)

Inductive msg : Set :=
| M1: N -> msg
| M2: str -> msg
| M3: N -> str -> msg
| BadTag: N -> msg.

Definition RecvMsg (c: chan) (m: msg) : Trace :=
  match m with
    | M1 p0 =>
      RecvNum c p0 ++
      RecvNum c 1
    | M2 p0 =>
      RecvStr c p0 ++
      RecvNum c 2
    | M3 p0 p1 =>
      RecvStr c p1 ++
      RecvNum c p0 ++
      RecvNum c 3
    | BadTag p0 =>
      (* special case for errors *)
      RecvNum c p0
  end.

Definition SendMsg (c: chan) (m: msg) : Trace :=
  match m with
    | M1 p0 =>
      SendNum c p0 ++
      SendNum c 1
    | M2 p0 =>
      SendStr c p0 ++
      SendNum c 2
    | M3 p0 p1 =>
      SendStr c p1 ++
      SendNum c p0 ++
      SendNum c 3
    | BadTag p0 =>
      (* special case for errors *)
      SendNum c 0
  end.

Definition recvMsg:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (m: msg) => tr ~~ traced (RecvMsg c m ++ tr) * bound c).
Proof.
  intros; refine (
    tag <- recvNum c
      tr;
    match tag with
      | 1 => (* M1 *)
        p0 <- recvNum c
          (tr ~~~ RecvNum c 1 ++ tr);
        {{ Return (M1 p0) }}
      | 2 => (* M2 *)
        p0 <- recvStr c
          (tr ~~~ RecvNum c 2 ++ tr);
        {{ Return (M2 p0) }}
      | 3 => (* M3 *)
        p0 <- recvNum c
          (tr ~~~ RecvNum c 3 ++ tr);
        p1 <- recvStr c
          (tr ~~~ RecvNum c p0 ++ RecvNum c 3 ++ tr);
        {{ Return (M3 p0 p1) }}
      | m =>
        {{ Return (BadTag m) }}
    end%N
  );
  sep fail auto.
Qed.

Definition sendMsg:
  forall (c: chan) (m: msg) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendMsg c m ++ tr) * bound c).
Proof.
  intros; refine (
    match m with
      | M1 p0 =>
        sendNum c 1
          tr;;
        sendNum c p0
          (tr ~~~ SendNum c 1 ++ tr);;
        {{ Return tt }}
      | M2 p0 =>
        sendNum c 2
          tr;;
        sendStr c p0
          (tr ~~~ SendNum c 2 ++ tr);;
        {{ Return tt }}
      | M3 p0 p1 =>
        sendNum c 3
          tr;;
        sendNum c p0
          (tr ~~~ SendNum c 3 ++ tr);;
        sendStr c p1
          (tr ~~~ SendNum c p0 ++ SendNum c 3 ++ tr);;
        {{ Return tt }}
      | BadTag _ =>
        sendNum c 0
          tr;;
        {{ Return tt }}
    end
  );
  sep fail auto.
Qed.

(*
   HANDLERS
*)

Inductive StepSpec : Trace -> Trace -> Trace -> Prop :=
| Echo :
  forall tr chan m,
  StepSpec tr
    (RecvMsg chan m)
    (SendMsg chan m).

Definition step:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (mm: msg * msg) =>
          tr ~~ traced (SendMsg c (fst mm) ++ RecvMsg c (snd mm) ++ tr) *
          [StepSpec tr (RecvMsg c (fst mm)) (SendMsg c (snd mm))] *
          bound c).
Proof.
  intros; refine (
    req <- recvMsg c
      tr;
    sendMsg c req
      (tr ~~~ RecvMsg c req ++ tr);;
    {{ Return (req, req) }}
  );
  sep fail auto.
  inv H; sep fail auto.

  apply himp_pure'.
  constructor; auto.
Qed.





Definition proto (m: msg) : list msg :=
  match m with
  | M1 p0 =>
    M1 p0 :: nil
  | _ =>
    nil
  end.

Lemma flat_map_app:
  forall A B (f: A -> list B) (l1 l2: list A),
  flat_map f (l1 ++ l2) = flat_map f l1 ++ flat_map f l2.
Proof.
  induction l1; simpl; intros; auto.
  rewrite IHl1; rewrite app_ass; auto.
Qed.

Fixpoint SendMsgs (c: chan) (ms: list msg) : Trace :=
  match ms with
    | nil =>
      nil
    | m::ms' =>
      SendMsgs c ms' ++ SendMsg c m
  end.

Definition sendMsgs:
  forall (c: chan) (ms: list msg) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (SendMsgs c ms ++ tr) * bound c).
Proof.
  intros; refine (
    Fix2
     (fun ms tr => tr ~~ traced tr * bound c)
     (fun ms tr (_: unit) => tr ~~ traced (SendMsgs c ms ++ tr) * bound c)
     (fun self ms tr =>
       match ms with
         | m::ms' =>
           sendMsg c m
             tr;;
           {{ self ms' (tr ~~~ SendMsg c m ++ tr) }}
         | nil =>
           {{ Return tt }}
       end)
     ms tr
  );
  sep fail auto.
  rewrite app_ass.
  sep fail auto.
Qed.

Definition turn:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (req: msg) => tr ~~ traced (SendMsgs c (proto req) ++ RecvMsg c req ++ tr) * bound c).
Proof.
  intros; refine (
    req <- recvMsg c
      tr;
    sendMsgs c (proto req)
      (tr ~~~ RecvMsg c req ++ tr);;
    {{ Return req }}
  );
  sep fail auto.
Qed.























Definition sendMsgs:
  forall (c: chan) (ms: list msg) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (_: unit) => tr ~~ traced (flat_map (SendMsg c) (rev ms) ++ tr) * bound c).
Proof.
  intros; refine (
    Fix2
     (fun ms tr => tr ~~ traced tr * bound c)
     (fun ms tr (_: unit) => tr ~~ traced (flat_map (SendMsg c) (rev ms) ++ tr) * bound c)
     (fun self ms tr =>
       match ms with
         | m::ms' =>
           sendMsg c m
             tr;;
           {{ self ms' (tr ~~~ SendMsg c m ++ tr) }}
         | nil =>
           {{ Return tt }}
       end)
     ms tr
  );
  sep fail auto.
  rewrite flat_map_app; simpl.
  repeat rewrite app_ass.
  sep fail auto.
Qed.

Definition turn:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (req: msg) =>
          tr ~~ traced (flat_map (SendMsg c) (rev (proto req)) ++ RecvMsg c req ++ tr) *
          [Turn tr (RecvMsg c req) (SendOptMsg c (proto req))] *
          bound c).
Proof.
  intros; refine (
    req <- recvMsg c
      tr;
    let orsp :=
      proto req
    in
    match orsp as orsp' return orsp = orsp' -> _ with
      | Some rsp => fun _ =>
        sendMsg c rsp
          (tr ~~~ RecvMsg c req ++ tr);;
        {{ Return req }}
      | None => fun _ =>
        {{ Return req }}
    end (refl_equal orsp)
  );
  sep fail auto;
  match goal with
    | H: proto ?req = _ |- _ =>
      rewrite H in *
  end;
  sep fail auto;
  apply himp_pure';
  constructor; auto.
Qed.






Inductive Turn : Trace -> Trace -> Trace -> Prop :=
| Reply :
  forall tr chan req rsp,
  proto req = Some rsp ->
  Turn tr
    (RecvMsg chan req)
    (SendMsg chan rsp)
| Quiet :
  forall tr chan req,
  proto req = None ->
  Turn tr
    (RecvMsg chan req)
    nil.

Definition SendOptMsg (c: chan) (om: option msg) : Trace :=
  match om with
    | Some m => SendMsg c m
    | None => nil
  end.

Definition turn:
  forall (c: chan) (tr: [Trace]),
  STsep (tr ~~ traced tr * bound c)
        (fun (req: msg) =>
          tr ~~ traced (SendOptMsg c (proto req) ++ RecvMsg c req ++ tr) *
          [Turn tr (RecvMsg c req) (SendOptMsg c (proto req))] *
          bound c).
Proof.
  intros; refine (
    req <- recvMsg c
      tr;
    let orsp :=
      proto req
    in
    match orsp as orsp' return orsp = orsp' -> _ with
      | Some rsp => fun _ =>
        sendMsg c rsp
          (tr ~~~ RecvMsg c req ++ tr);;
        {{ Return req }}
      | None => fun _ =>
        {{ Return req }}
    end (refl_equal orsp)
  );
  sep fail auto;
  match goal with
    | H: proto ?req = _ |- _ =>
      rewrite H in *
  end;
  sep fail auto;
  apply himp_pure';
  constructor; auto.
Qed.