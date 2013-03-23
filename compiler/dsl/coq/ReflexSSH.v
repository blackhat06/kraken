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
 
Notation LoginReq :=       (None) (only parsing).
Notation LoginResT :=      (Some None) (only parsing).
Notation LoginResF :=      (Some (Some None)) (only parsing).
      
Notation PubkeyReq :=      (Some (Some (Some None))) (only parsing).
Notation PubkeyRes :=      (Some (Some (Some (Some None)))) (only parsing).

Notation KeysignReq :=     (Some (Some (Some (Some (Some None))))) (only parsing).
Notation KeysignRes :=     (Some (Some (Some (Some (Some (Some None)))))) (only parsing).

Notation CreatePtyerReq := (Some (Some (Some (Some (Some (Some (Some None))))))) (only parsing).
Notation CreatePtyerRes := (Some (Some (Some (Some (Some (Some (Some (Some None)))))))) (only parsing).

    (* monitor <-> system *)
Notation SLoginReq :=      (Some (Some (Some (Some (Some (Some (Some (Some (Some None))))))))) (only parsing).
Notation SLoginResT :=     (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None)))))))))) (only parsing).
Notation SLoginResF :=     (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None))))))))))) (only parsing).

Notation SPubkeyReq :=     (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None)))))))))))) (only parsing).
Notation SPubkeyRes :=     (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None))))))))))))) (only parsing).

Notation SKeysignReq :=    (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None)))))))))))))) (only parsing).
Notation SKeysignRes :=    (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None))))))))))))))) (only parsing).

Notation SCreatePtyerReq := (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None)))))))))))))))) (only parsing).
Notation SCreatePtyerRes := (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some None))))))))))))))))) (only parsing).


Definition KSTD : vdesc := mk_vdesc
  [ fd_d (* system *)
  ; fd_d (* slave *)
  ; num_d (* authenticated *)
  ; str_d (* authenticated username *)
  ].

Notation v_st_system := (None) (only parsing).
Notation v_st_slave := (Some None) (only parsing).
Notation v_st_authenticated := (Some (Some None)) (only parsing).
Notation v_st_auth_user := (Some (Some (Some None))) (only parsing).

Notation system := (StVar _ KSTD _ _ v_st_system) (only parsing).
Notation slave := (StVar _ KSTD _ _ v_st_slave) (only parsing).
Notation authenticated := (StVar _ KSTD _ _ v_st_authenticated) (only parsing).
Notation auth_user := (StVar _ KSTD _ _ v_st_auth_user) (only parsing).

Definition IENVD : vdesc := mk_vdesc
  [ fd_d (* system *)
  ; fd_d (* slave *)
  ].

Notation v_env_system := (None) (only parsing).
Notation v_env_slave := (Some None) (only parsing).

Inductive COMPT : Type := System | Slave.

Definition COMPS (t : COMPT) : comp :=
  match t with
  | System   => mk_comp "System"
                        "/home/don/kraken/kraken/ssh-proto/kmsg-ssh/sshd_sys"
                        []
  | Slave    => mk_comp "Slave"
                        "/home/don/kraken/kraken/ssh-proto/kmsg-ssh/ssh"
                        []
  end.

Definition NB_CFGD := 2.

Definition CFGD := mk_vvdesc
  [ ("System", [str_d])
  ; ("Slave", [])
  ].

Notation t_sys_cfg := (None) (only parsing).
Notation t_slv_cfg := (Some None) (only parsing).

Definition INIT : init_prog PAYD COMPT KSTD CFGD (init_msg PAYD) IENVD :=
  [ fun s => Spawn _ _ _ CFGD _ IENVD System
                   t_sys_cfg (str_of_string "System", tt)
                   v_env_system (Logic.eq_refl _)
  ; fun s => Spawn _ _ _ CFGD _ IENVD Slave
                   t_slv_cfg tt
                   v_env_slave (Logic.eq_refl _)
  ].

Notation t_system_pat := (None) (only parsing).
Definition system_pat := (Some (str_of_string "System"), tt).

Definition HANDLERS : handlers PAYD COMPT KSTD CFGD :=
  (fun m cfd =>
    match tag PAYD m as _tm return
      @sdenote _ SDenoted_vdesc (lkup_tag PAYD _tm) -> _
    with
      (* login *)

    | LoginReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         let (loginstr, _) := pl in
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ system
                            SLoginReq (SLit _ _ _ _ loginstr, tt)
            ]
         )
       )

    | SLoginResT => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         let (user, _) := pl in           
         (fun st0 =>
            if exists_comp (Some cfd) CFGD t_system_pat
                           system_pat (kcs _ _ _ st0)
            then
            [ 
              
              fun s => StUpd PAYD _ KSTD _ _ _ v_st_auth_user
                             strd_neq_fdd (SLit _ _ _ _ user)
              ; 
              fun s => StUpd PAYD _ KSTD _ _ _ v_st_authenticated
                             numd_neq_fdd (NLit _ _ _ _ (num_of_nat 1))
              ;
              fun s => Send PAYD _ _ _ _ _ slave LoginResT tt
            ]
            else []
         )
       )

    | SLoginResF => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ slave LoginResF tt
            ]
         )
       )

       (* pub key request *)

    | PubkeyReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ system SPubkeyReq tt
            ]
         )
       )

    | SPubkeyRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         let (pubkey, _) := pl in
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ system
                            SPubkeyRes (SLit _ _ _ _ pubkey, tt)
            ]
         )
       )
       
       (* key sign *)

    | KeysignReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         let (keystr, _) := pl in
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ system
                            SKeysignReq (SLit _ _ _ _ keystr, tt)
            ]
         )
       )

    | SKeysignRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         let (signedkey, _) := pl in
         (fun st0 =>
            [ fun s => Send PAYD _ _ _ _ _ system
                            KeysignRes (SLit _ _ _ _ signedkey, tt)
            ]
         )
       )

       (* create pseudo terminal *)

    | CreatePtyerReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 =>
           if num_eq (shvec_ith _ (projT2 KSTD:svec desc 4)
                                (kst _ _ _ st0)
                                v_st_authenticated)
                     (num_of_nat 0)
           then []
           else [ 
               fun s => Send PAYD _ _ _ _ _ system
                             SCreatePtyerReq (auth_user,tt)
             ]
         )
       )

    | SCreatePtyerRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         match pl with 
           | (fd0, (fd1, _)) =>
             (fun st0 =>
               [ fun s => Send PAYD _ _ _ _ _
                               system CreatePtyerRes
                               (CFd PAYD _ _ _, (CFd PAYD _ _ _, tt))
               ]
             )
         end
       )
       

       (* not meant to be received by the kernel *)
    | LoginResT => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | LoginResF => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | PubkeyRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | KeysignRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | CreatePtyerRes => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | SLoginReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | SPubkeyReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | SKeysignReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | SCreatePtyerReq => fun pl =>
       let envd := mk_vdesc [] in
       existT (fun d => hdlr_prog PAYD COMPT KSTD CFGD _ d) envd (
         (fun st0 => [])
       )
    | (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some bad)))))))))))))))))) => fun _ =>
      match bad with end
    end (pay PAYD m)
  ).

Definition main := mk_main (Build_spec NB_MSG PAYD IENVD KSTD COMPT COMPS NB_CFGD CFGD INIT HANDLERS).
