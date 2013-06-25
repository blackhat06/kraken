Require Import String.

Require Import Reflex.
Require Import ReflexBase.
Require Import ReflexDenoted.
Require Import ReflexFin.
Require Import ReflexVec.
Require Import ReflexHVec.
Require Import ReflexFrontend.

Open Scope string_scope.

(*
 This SSH monitor works as follows :
 1) the SSH monitor(MON) creates 3 different comps : SYS, SLV, PTY
 2) MON waits till SLV sends LoginReq

 == Login Request
 1) SLV asks MON to login via LoginReq,
 1-1) if login_cnt =n 3 then send Login_Res(0) back to SLV
 1-2) otherwise, login_cnt = login_cnt + 1, then send SysLogReq()
 to SYS

 2) SYS replies to MON with SysLogRes()
 if the response is 1 then set login_succeded = 1; and
 login_account = $account and MON delivers it to SLV with LogRes

 == PubKey Request
 1) SLV asks MON for the public key via PubKeyReq
 MON delivers it to SYS via SysPubKeyReq

 2) SYS replies to MON with SysPubKeyRes
 MON delivers it to SLV

 == KeySign Request(str)/IOCTL(fdesc)
 works in the same as as PubKeyRequest

 == CreatePtyer
 1) SLV asks MON for a created PTYER
 1-1) if login_succeeded =n 0 then ignore this request completely
 and don't send anything back

 2) MON creates a PTY by sending SysCreatePtyReq()
 3) SYS sends back with SysCreatPtyRes(fdesc, fdesc)
 (SYS applies ioctl() to the slave fd & it creates a ptyer inside it
 (Question: there are two options : a. create ptyer inside SYS
 b. spawns a ptyer as a component from MON. Which one is better?? )

 4) MON replies back to SLV with the two file descriptors
*)

Module SystemFeatures <: SystemFeaturesInterface.

Definition NB_MSG : nat := 18.

Definition PAYD : vvdesc NB_MSG := mk_vvdesc
  [
    (* slave <- monitor *)
    ("LoginReq",   [str_d]);
    ("LoginResT",   []);
    ("LoginResF",   []);

    ("PubkeyReq",   []);
    ("PubkeyRes",   [str_d]);

    ("KeysignReq",   [str_d]);
    ("KeysignRes",   [str_d]);

    ("CreatePtyerReq",   []);
    ("CreatePtyerRes",   [fd_d; fd_d]);

    (* monitor <-> system *)
    ("SLoginReq",   [str_d]);
    ("SLoginResT",   [str_d]);
    ("SLoginResF",   []);

    ("SPubkeyReq",   []);
    ("SPubkeyRes",   [str_d]);

    ("SKeysignReq",   [str_d]);
    ("SKeysignRes",   [str_d]);

    ("SCreatePtyerReq",   [str_d]);
    ("SCreatePtyerRes",   [fd_d; fd_d])
  ].

Inductive COMPT' : Type := System | Slave.

Definition COMPT := COMPT'.

Definition COMPTDEC : forall (x y : COMPT), decide (x = y).
Proof. decide equality. Defined.

Definition COMPS (t : COMPT) : compd :=
  match t with
  | System => mk_compd
                "System" "/home/don/kraken/kraken/ssh-proto/kmsg-ssh/sshd_sys" []
                (mk_vdesc [str_d])
  | Slave  => mk_compd
                "Slave"  "/home/don/kraken/kraken/ssh-proto/kmsg-ssh/ssh"      []
                (mk_vdesc [])
  end.

Notation LoginReq        := 0%fin (only parsing).
Notation LoginResT       := 1%fin (only parsing).
Notation LoginResF       := 2%fin (only parsing).
Notation PubkeyReq       := 3%fin (only parsing).
Notation PubkeyRes       := 4%fin (only parsing).
Notation KeysignReq      := 5%fin (only parsing).
Notation KeysignRes      := 6%fin (only parsing).
Notation CreatePtyerReq  := 7%fin (only parsing).
Notation CreatePtyerRes  := 8%fin (only parsing).
Notation SLoginReq       := 9%fin (only parsing).
Notation SLoginResT      := 10%fin (only parsing).
Notation SLoginResF      := 11%fin (only parsing).
Notation SPubkeyReq      := 12%fin (only parsing).
Notation SPubkeyRes      := 13%fin (only parsing).
Notation SKeysignReq     := 14%fin (only parsing).
Notation SKeysignRes     := 15%fin (only parsing).
Notation SCreatePtyerReq := 16%fin (only parsing).
Notation SCreatePtyerRes := 17%fin (only parsing).

Definition IENVD : vcdesc COMPT := mk_vcdesc
  [ Comp _ System; Comp _ Slave ].

Notation v_env_system := (None) (only parsing).
Notation v_env_slave  := (Some None) (only parsing).

Definition KSTD : vcdesc COMPT := mk_vcdesc
  [ Comp _ System
  ; Comp _ Slave
  ; Desc _ num_d (* authenticated *)
  ; Desc _ str_d (* authenticated username *)
  ].

Notation v_st_system        := (None) (only parsing).
Notation v_st_slave         := (Some None) (only parsing).
Notation v_st_authenticated := (Some (Some None)) (only parsing).
Notation v_st_auth_user     := (Some (Some (Some None))) (only parsing).

End SystemFeatures.

Import SystemFeatures.

Module Language := MkLanguage(SystemFeatures).

Import Language.

Module Spec <: SpecInterface.

Include SystemFeatures.

Definition INIT : init_prog PAYD COMPT COMPS KSTD IENVD :=
  [ fun s => spawn IENVD _ System (str_of_string "System", tt) v_env_system (Logic.eq_refl _)
  ; fun s => spawn IENVD _ Slave  tt                           v_env_slave  (Logic.eq_refl _)
  ].

Definition system_pat := (Some (str_of_string "System"), tt).

Definition exists_comp := exists_comp COMPT COMPTDEC COMPS.

Definition HANDLERS : handlers PAYD COMPT COMPS KSTD :=
  (fun m cc =>
     let (ct, cf, _) := cc in
     match tag PAYD m as _tm return
       @sdenote _ SDenoted_vdesc (lkup_tag PAYD _tm) -> _
     with

     | LoginReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         let (loginstr, _) := pl in
         (fun st0 =>
            [ fun s => sendall envd _
                               (mk_comp_pat
                                  System
                                  (Some (comp_fd st0##v_st_system%kst))
                                  (None, tt)
                               )
                               SLoginReq (slit loginstr, tt)
            ]
         )
       )

     | SLoginResT => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         let (user, _) := pl in
         (fun st0 =>
            match ct with
            | System =>
              [ fun s => stupd envd _ v_st_auth_user     (slit user)
              ; fun s => stupd envd _ v_st_authenticated (nlit (num_of_nat 1))
              ; fun s => sendall envd _
                                 (mk_comp_pat
                                    Slave
                                    (Some (comp_fd st0##v_st_slave%kst))
                                    tt
                                 )
                                 LoginResT tt
              ]
            | _ =>
              []
            end
         )
       )

     | SLoginResF => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 =>
            [ fun s => sendall envd _
                       (mk_comp_pat
                          Slave
                          (Some (comp_fd st0##v_st_slave%kst))
                          tt
                       )
                       LoginResF tt
            ]
         )
       )

     | PubkeyReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 =>
            [ fun s => sendall envd _
                               (mk_comp_pat
                                  System
                                  (Some (comp_fd st0##v_st_system%kst))
                                  (None, tt)
                               )
                               SPubkeyReq tt
            ]
         )
       )

     | SPubkeyRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         let (pubkey, _) := pl in
         (fun st0 =>
            [ fun s => sendall envd _
                               (mk_comp_pat
                                  System
                                  (Some (comp_fd st0##v_st_system%kst))
                                  (None, tt)
                               )
                               SPubkeyRes (slit pubkey, tt)
            ]
         )
       )

     | KeysignReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         let (keystr, _) := pl in
         (fun st0 =>
            [ fun s => sendall envd _
                               (mk_comp_pat
                                  System
                                  (Some (comp_fd st0##v_st_system%kst))
                                  (None, tt)
                               )
                               SKeysignReq (slit keystr, tt)
            ]
         )
       )

     | SKeysignRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         let (signedkey, _) := pl in
         (fun st0 =>
            [ fun s => sendall envd _
                               (mk_comp_pat
                                  System
                                  (Some (comp_fd st0##v_st_system%kst))
                                  (None, tt)
                               )
                               KeysignRes (slit signedkey, tt)
            ]
         )
       )

     | CreatePtyerReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 =>
           if num_eq
                (st0##v_st_authenticated%kst)
                (num_of_nat 0)
           then []
           else [ fun s => sendall envd _
                                   (mk_comp_pat
                                      System
                                      (Some (comp_fd st0##v_st_system%kst))
                                      (None, tt)
                                   )
                                   SCreatePtyerReq (stvar v_st_auth_user, tt)
                ]
         )
       )

     | SCreatePtyerRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         match pl with
         | (fd0, (fd1, _)) =>
           (fun st0 =>
              [ fun s => sendall envd _
                                 (mk_comp_pat
                                    System
                                    (Some (comp_fd st0##v_st_system%kst))
                                    (None, tt)
                                 )
                                 CreatePtyerRes (cfd, (cfd, tt))
              ]
           )
         end
       )

     (* not meant to be received by the kernel *)
     | LoginResT => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | LoginResF => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | PubkeyRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | KeysignRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | CreatePtyerRes => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | SLoginReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | SPubkeyReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | SKeysignReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | SCreatePtyerReq => fun pl =>
       let envd := mk_vcdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT COMPS KSTD cc _ d) envd (
         (fun st0 => [])
       )

     | (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some bad)))))))))))))))))) => fun _ =>
      match bad with end
    end (pay PAYD m)
  ).

End Spec.

Module Main := MkMain(Spec).
Import Main.

Require Import PolLang.
Require Import ActionMatch.
Require Import Tactics.
Require Import Ynot.

Import Spec.

Local Opaque str_of_string.

Ltac destruct_fin f :=
  match type of f with
  | False => destruct f
  | _ => let f' := fresh "f" in
         destruct f as [ f' | ]; [destruct_fin f' | ]
  end.

Ltac destruct_pay pay :=
  vm_compute in pay;
  match type of pay with
  | unit => idtac
  | _ =>
    let x := fresh "x" in
    let r := fresh "r" in
    destruct pay as [x r]; simpl in x; destruct_pay r
  end.

Ltac destruct_msg :=
  match goal with [ m : msg _ |- _ ] =>
    let tag := fresh "tag" in
    let pay := fresh "pay" in
    destruct m as [tag pay]; destruct_fin tag; destruct_pay pay
  end.

(*Destructs num, str, or fd equalities in the context.*)
Ltac destruct_eq H :=
  repeat match type of H with
         | context[if ?x then _ else _ ]
           => destruct x
         end.

Ltac destruct_input input :=
  unfold cmd_input in *;
  simpl in *; (*compute in input;*)
  match type of input with
  | unit => idtac
  | _ => let x := fresh "x" in
         let input' := fresh "input'" in
         destruct input as [x input']; destruct_input input'
  end.

Ltac unpack_inhabited Htr :=
  match type of Htr with
  | _ = inhabits ?tr
     => simpl in Htr; apply pack_injective in Htr; subst tr
  end.

Ltac unpack :=
  match goal with
  | [ Htr : ktr _ _ _ _ ?s = inhabits ?tr |- _ ] =>
    match goal with
    (*Valid exchange.*)
    | [ c : comp _ _, _ : ?s' = _,
        input : kstate_run_prog_return_type _ _ _ _ _ _ _ _ ?s' _ |- _ ] =>
      subst s'; destruct c; destruct_eq Htr; destruct_input input
    (*Initialization.*)
    | [ s : init_state _ _ _ _ _,
        input : init_state_run_prog_return_type _ _ _ _ _ _ _ _ |- _ ] =>
      match goal with
      | [ H : s = _ |- _ ] =>
        rewrite H in Htr; destruct_input input
      end
    (*Bogus msg*)
    | [ c : comp _ _ |- _ ] =>
      subst s; destruct c
    end(*; unpack_inhabited Htr*)
  end.

Ltac destruct_unpack :=
  match goal with
  | [ m : msg _ |- _ ]
      => destruct_msg; unpack
  | _
      => unpack
  end.

Ltac reach_induction :=
  intros;
  match goal with
  | [ _ : ktr _ _ _ _ _ = inhabits ?tr, H : Reach _ _ _ _ _ _ _ _ _ |- _ ]
      => generalize dependent tr; induction H;
         (*Do not put simpl anywhere in here. It breaks destruct_unpack.*)
         intros; destruct_unpack
  end.

Theorem Enables_app : forall A B tr tr',
  (forall elt, List.In elt tr' -> ~ PolLang.AMatch PAYD COMPT COMPS COMPTDEC B elt) ->
  Enables PAYD COMPT COMPS COMPTDEC A B tr ->
  Enables PAYD COMPT COMPS COMPTDEC A B (tr' ++ tr)%list.
Proof.
  intros. induction tr'.
  now simpl.
  apply E_not_future. apply IHtr'. intros. apply H. now right.
  apply H. now left.
Qed.

Theorem auth_priv : forall st tr u,
  Reach PAYD COMPT COMPTDEC COMPS KSTD IENVD INIT HANDLERS st ->
  ktr _ _ _ _ st = inhabits tr ->
  Enables PAYD COMPT COMPS COMPTDEC
          (KORecv PAYD COMPT COMPS None
                  (Some (Build_opt_msg PAYD
                                       SLoginResT (Some u, tt))))
          (KOSend PAYD COMPT COMPS None
                  (Some (Build_opt_msg PAYD
                                       SCreatePtyerReq (Some u, tt))))
          tr.
Proof.
  admit. (*reach_induction.*)
Qed.