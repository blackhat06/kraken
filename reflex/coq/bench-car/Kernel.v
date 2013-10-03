Require Import String.

Require Import Reflex.
Require Import ReflexBase.
Require Import ReflexDenoted.
Require Import ReflexFin.
Require Import ReflexFrontend.
Require Import ReflexHVec.
Require Import ReflexIO.
Require Import ReflexVec.

Open Scope string_scope.

Module SystemFeatures <: SystemFeaturesInterface.

Definition NB_MSG : nat := 6.

Definition PAYD : vvdesc NB_MSG := mk_vvdesc
  [
    ("Crash",   []);
    ("Acceleration",   []);
    ("DoorsOpen",   []);
    ("UnlockDoors",   []);
    ("VolumeUp",   []);
    ("VolumeDown",   [])
  ].

Inductive COMPT' : Type := Engine | Doors | Radio.

Definition COMPT := COMPT'.

Definition COMPTDEC : forall (x y : COMPT), decide (x = y).
Proof. decide equality. Defined.

Definition COMPS (t : COMPT) : compd :=
  match t with
  | Engine => mk_compd
                "Engine" "engine.c" []
                (mk_vdesc [])
  | Doors => mk_compd
                "Doors"  "doors.c"      []
                (mk_vdesc [])
  | Radio => mk_compd
                "Radio"  "radio.c"    []
                (mk_vdesc [])
  end.

Notation Crash        := 0%fin (only parsing).
Notation Acceleration       := 1%fin (only parsing).
Notation DoorsOpen       := 2%fin (only parsing).
Notation UnlockDoors       := 3%fin (only parsing).
Notation VolumeUp       := 4%fin (only parsing).
Notation VolumeDown      := 5%fin (only parsing).

Definition IENVD : vcdesc COMPT := mk_vcdesc
  [ Comp _ Engine; Comp _ Doors; Comp _ Radio ].

Notation v_env_engine := 0%fin (only parsing).
Notation v_env_doors  := 1%fin (only parsing).
Notation v_env_radio  := 2%fin (only parsing).

Definition KSTD : vcdesc COMPT := mk_vcdesc
  [ Comp _ Engine
  ; Comp _ Doors
  ; Comp _ Radio
  ].

Notation v_st_engine        := 0%fin (only parsing).
Notation v_st_doors         := 1%fin (only parsing).
Notation v_st_radio         := 2%fin (only parsing).

End SystemFeatures.

Import SystemFeatures.

Module Language := MkLanguage(SystemFeatures).

Import Language.

Module Spec <: SpecInterface.

Include SystemFeatures.

Definition INIT : init_prog PAYD COMPT COMPS KSTD IENVD :=
   seq (spawn _ IENVD Engine tt v_env_engine (Logic.eq_refl _))
  (seq (stupd _ IENVD v_st_engine (i_envvar IENVD v_env_engine))
  (seq (spawn _ IENVD Doors  tt v_env_doors  (Logic.eq_refl _))
  (seq (stupd _ IENVD v_st_doors (i_envvar IENVD v_env_doors))
  (seq (spawn _ IENVD Radio  tt v_env_radio  (Logic.eq_refl _))
       (stupd _ IENVD v_st_radio (i_envvar IENVD v_env_radio)))))).

Open Scope hdlr.
Definition HANDLERS : handlers PAYD COMPT COMPS KSTD :=
  fun t ct =>
  match ct as _ct, t as _t return
    {prog_envd : vcdesc COMPT & hdlr_prog PAYD COMPT COMPS KSTD _ct _t prog_envd}
  with
     | Engine, Crash =>
       [[ mk_vcdesc [] :
          send (stvar v_st_doors) UnlockDoors tt
       ]]
     | Engine, Acceleration =>
       [[ mk_vcdesc [] :
          send (stvar v_st_radio) VolumeUp tt
       ]]
     | Doors, DoorsOpen =>
       [[ mk_vcdesc [] :
          send (stvar v_st_radio) VolumeDown tt
       ]]
     | _, _ => [[ mk_vcdesc [] : nop ]]
    end.

<<<<<<< Updated upstream:reflex/coq/bench-car/Kernel.v
=======
Require Import NIExists.
Require Import PruneFacts.

Definition clblr :=
  [Build_conc_pat COMPT COMPS Engine tt].

Definition vlblr (f : fin (projT1 KSTD)) := false.

Local Opaque str_of_string.

Theorem ni : NI PAYD COMPT COMPTDEC COMPS
  IENVD KSTD INIT HANDLERS clblr vlblr.
Proof.
  intros; apply ni_suf_all.
Local Opaque cmd_ok_low.
    Time unfold low_ok''; intros;
    destruct_msg'; destruct_comp';
    try discriminate; simpl;
      repeat first [apply nop_low
        | apply seq_low
        | apply ite_low
        | apply stupd_low
        | solve [apply send_low_ccomp]
        | apply send_low
        | apply call_low
        | solve [auto] ].

Local Opaque all_cmd_ok_high.
    Time unfold high_ok_all; intros;
    destruct_msg'; destruct_comp';
    try discriminate; simpl;
      repeat first [apply nop_high_all
        | apply seq_high_all
        | apply ite_high_all
        | apply stupd_high_all
        | solve [apply send_high_all_low_comp; auto]
        | apply send_high_all
        | apply spawn_high_all
        | apply call_high_all
        | solve [auto ] ].
Qed.

>>>>>>> Stashed changes:reflex/coq/ReflexCar.v
End Spec.

Module Main := MkMain(Spec).
Import Main.