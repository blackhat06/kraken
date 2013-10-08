Require Import String.

Require Import Reflex.
Require Import ReflexBase.
Require Import ReflexDenoted.
Require Import ReflexFin.
Require Import ReflexFrontend.
Require Import ReflexHVec.
Require Import ReflexIO.
Require Import ReflexVec.

Definition splitAt c s :=
  let fix splitAt_aux c s r_res :=
    match s with
    | nil    => (List.rev r_res, nil)
    | h :: t =>
      if Ascii.ascii_dec h c then (List.rev r_res, t) else splitAt_aux c t (h :: r_res)
    end
  in splitAt_aux c s nil.

Open Scope string_scope.

Module SystemFeatures <: SystemFeaturesInterface.

Definition NB_MSG : nat := 12.

(*Cookies:
For now, we won't have cookies go through the kernel. Instead, when
a tab is spawned for a new domain, a new cookie proc will be spawned for that
domain. The fd for that cookie proc will be sent to the tab and the fd for the
tab will be sent to the cookie proc. Each subsequent tab spawned for that domain
will be sent the fd of the cookie proc and the cookie proc will be sent the fd
of the new tab.*)

Definition PAYD : vvdesc NB_MSG := mk_vvdesc
  [ ("Display",     [str_d])
  ; ("Navigate",    [str_d])
  ; ("ReqResource", [str_d])
  ; ("ResResource", [fd_d])
  ; ("ReqSocket",   [str_d])
  ; ("ResSocket",   [fd_d])
  ; ("SetDomain",   [str_d])
  ; ("KeyPress",    [str_d])
  ; ("MouseClick",  [str_d; str_d; num_d])
  ; ("Go",          [str_d])
  ; ("NewTab",      [str_d])
  ; ("CProcFD", [fd_d])
  ].

Notation Display     := 0%fin (only parsing).
Notation Navigate    := 1%fin (only parsing).
Notation ReqResource := 2%fin (only parsing).
Notation ResResource := 3%fin (only parsing).
Notation ReqSocket   := 4%fin (only parsing).
Notation ResSocket   := 5%fin (only parsing).
Notation SetDomain   := 6%fin (only parsing).
Notation KeyPress    := 7%fin (only parsing).
Notation MouseClick  := 8%fin (only parsing).
Notation Go          := 9%fin (only parsing).
Notation NewTab      := 10%fin (only parsing).
Notation CProcFD     := 11%fin (only parsing).

Inductive COMPT' : Set := UserInput | Output | Tab | CProc | DomainBar.

Definition COMPT := COMPT'.

Definition COMPTDEC : forall (x y : COMPT), decide (x = y).
Proof. decide equality. Defined.

Definition test_dir := "../test/quark/".
Definition create_socket := "createsocket.py".
Definition wget := "wget.py".

Definition COMPS (t : COMPT) : compd :=
  match t with
  | UserInput => mk_compd "UserInput" (test_dir ++ "user-input.py")       [] (mk_vdesc [])
  | Output    => mk_compd "Output"    (test_dir ++ "screen.py")    [] (mk_vdesc [])
  | Tab       => mk_compd "Tab"       (test_dir ++ "tab.py")     [] (mk_vdesc [str_d])
  | CProc     => mk_compd "CProc"     (test_dir ++ "cproc.py")     [] (mk_vdesc [str_d])
  | DomainBar => mk_compd "DomainBar" (test_dir ++ "domainbar.py") [] (mk_vdesc [])
  end.

Definition IENVD : vcdesc COMPT := mk_vcdesc
  [ Comp _ Output; Comp _ Tab; Comp _ UserInput ].

Notation i_output    := 0%fin (only parsing).
Notation i_curtab    := 1%fin (only parsing).
Notation i_userinput := 2%fin (only parsing).

Definition KSTD : vcdesc COMPT := mk_vcdesc
  [ Comp _ Output; Comp _ Tab ].

Notation v_output := (None) (only parsing).
Notation v_curtab := (Some None) (only parsing).

End SystemFeatures.

Import SystemFeatures.

Module Language := MkLanguage(SystemFeatures).

Import Language.

Definition default_domain := str_of_string "google.com".
Definition default_url := str_of_string "http://www.google.com".

Module Spec <: SpecInterface.

Include SystemFeatures.

Open Scope char_scope.
Definition dom {envd term} s :=
  (splitfst envd term "/" (splitsnd envd term "." s)).

Definition dom' s :=
  let url_end := snd (splitAt "." s) in
  fst (splitAt "/" url_end).
Close Scope char_scope.

Definition INIT : init_prog PAYD COMPT COMPS KSTD IENVD :=
  seq (spawn _ IENVD Output    tt                   i_output    (Logic.eq_refl _)) (
  seq (spawn _ IENVD Tab       (i_slit default_domain, tt) i_curtab    (Logic.eq_refl _)) (
  seq (spawn _ IENVD UserInput tt                   i_userinput (Logic.eq_refl _)) (
  seq (send (i_envvar IENVD i_curtab) Go (i_slit default_url, tt)) (
  seq (stupd _ IENVD v_output (Term _ (base_term _ ) _ (Var _ IENVD i_output))) (
  seq (stupd _ IENVD v_curtab (Term _ (base_term _ ) _ (Var _ IENVD i_curtab))
  ) nop))))).

Definition cur_tab_dom {t envd} :=
  cconf (envd:=envd) (t:=t) Tab Tab 0%fin (CComp PAYD COMPT COMPS KSTD Tab t envd).

Open Scope hdlr.
Definition HANDLERS : handlers PAYD COMPT COMPS KSTD :=
  fun t ct =>
  match ct as _ct, t as _t return
    {prog_envd : vcdesc COMPT & hdlr_prog PAYD COMPT COMPS KSTD _ct _t prog_envd}
  with
  | _, Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some (Some bad))))))))))) =>
    match bad with end

  | Tab, ReqSocket =>
    let envd := mk_vcdesc [Desc _ fd_d] in
    [[ envd :
       ite (eq (dom (mvar ReqSocket None)) cur_tab_dom)
       (
         seq (call _ envd (slit (str_of_string (create_socket)))
                                [mvar ReqSocket 0%fin] 0%fin (Logic.eq_refl _))
             (send ccomp ResSocket (envvar envd None, tt))
       )
       (
         nop
       )
    ]]
  | Tab, Display =>
      [[ mk_vcdesc [] :
         ite (eq ccomp (stvar v_curtab))
             (
               send (stvar v_output) Display (mvar Display None, tt)
             )
             (
               nop
             )
       ]]
  | Tab, ReqResource =>
      let envd := mk_vcdesc [Desc _ fd_d] in
      [[ envd :
         ite (eq (dom (mvar ReqResource None)) cur_tab_dom)
             (
               seq (call _ envd (slit (str_of_string (wget)))
                                 [mvar ReqResource None] None (Logic.eq_refl _))
                   (send ccomp ResResource (envvar envd None, tt))

             )
             (
               nop
             )
       ]]
  | Tab, CProcFD =>
      let envd := mk_vcdesc [Comp _ CProc] in
      [[ envd :
        complkup (envd:=envd) (mk_comp_pat _ _ CProc (Some cur_tab_dom, tt))
                 (send (envvar (mk_vcdesc [Comp _ CProc; Comp _ CProc]) 1%fin)
                   CProcFD (mvar CProcFD 0%fin, tt))
                 (seq (spawn _ envd CProc (cur_tab_dom, tt) 0%fin (Logic.eq_refl _)) (
                      (send (envvar envd 0%fin) CProcFD (mvar CProcFD 0%fin, tt))))
      ]]
  | UserInput, KeyPress =>
      [[ mk_vcdesc [] :
      seq (send (stvar v_curtab) KeyPress (mvar KeyPress None, tt))
      nop ]]
  | UserInput, MouseClick =>
      [[ mk_vcdesc [] :
      seq (send (stvar v_curtab) MouseClick
        (mvar MouseClick 0%fin, (mvar MouseClick 1%fin, (mvar MouseClick 2%fin, tt))))
      nop ]]
  | UserInput, NewTab =>
      let envd := mk_vcdesc [Comp _ Tab] in
      [[ envd :
         seq (spawn _ envd Tab (mvar NewTab 0%fin, tt) 0%fin (Logic.eq_refl _)) (
         seq (stupd _ envd v_curtab (envvar envd 0%fin)) (
         seq (send (stvar v_curtab) Go (slit default_url, tt))
             nop))
      ]]
  | _, _ =>
    [[ mk_vcdesc [] : nop ]]
  end.
Close Scope hdlr.

End Spec.

Module Main := MkMain(Spec).
