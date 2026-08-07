# AutoPMX PopPK NONMEM Model Library

This library is the syntax anchor for DuDu PMx automated model building. Local LLMs should NOT draft NONMEM control streams from memory. They should choose the closest template below, fill the placeholders, and only make focused edits supported by diagnostics.

## Global Rules

- Always start automated model building with the simplest defensible structural model for the detected route.
- Prefer library templates over free-form NONMEM syntax.
- Keep `$DATA {DATA_FILE} IGNORE=C` unless the user explicitly changes the dataset/comment flag.
- Treat the CSV header as the source of truth for `$INPUT`: labels must appear in the same order as the data file columns.
- The `C` column must remain a literal `C` token and must never be written as `C=DROP`, `C=SKIP`, omitted, or moved away from its CSV position.
- Use semicolon labels on `$THETA`, `$OMEGA`, and `$SIGMA`; the parameter extraction pipeline relies on these labels.
- ETA numbering must always be contiguous (ETA1..ETAn). When fixing/removing IIV, either keep the ETA with `0 FIX` or remove the OMEGA row and renumber every ETA reference in `$PK`, `$OMEGA`, and `$TABLE`.
- Default residual error is combined proportional plus additive.
- Use `S1=V/1000` (or `S1=V` when units align, e.g. AMT=mg + DV=µg/mL where mg/L=µg/mL) for IV central observations in compartment 1. Use `S2=V/1000` for extravascular models. S1/S2 MUST always be the LAST line of $PK — the variables they reference (V, V1, V2) must be defined first.
  ⚠ S1 scaling rule: S1=V/1000 is only correct when AMT & DV units require a 1000× scaling (e.g. mg+ng/mL → V in ×10³ L). When mg/L = µg/mL numerically (e.g. AMT=mg, DV=µg/mL), use S1=V (no /1000). The correct expression is determined by your dataset's unit configuration.
- Keep `$EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10` and `$COVARIANCE PRINT=E MATRIX=S`.
- Keep generated run IDs consistent in all table filenames.
- **IIV POLICY**: Every PK parameter in EVERY template (1-cmt, 2-cmt, 3-cmt) starts WITH IIV (EXP(ETA(n))) and a corresponding $OMEGA row (0.04 for peripheral params). This is the DEFAULT. IIV on peripheral parameters (Q, V2, Q3, V3) should only be fixed/removed when diagnostics show RSE > 50% (relative standard error of the IIV variance), repeated convergence/covariance failure, or a boundary estimate. Eta-shrinkage is a reporting/diagnostic metric only; it must NOT be used to add, remove, fix, or accept/reject IIV. ETA and PK parameter decisions use %RSE, boundary, covariance, and convergence. If a parameter has no ETA, do not report or infer eta-shrinkage for it. When a model converges successfully with fixed IIV, do NOT automatically unfix it in the next run; anti-oscillation wins and `0 FIX` may remain final. Re-exploration is allowed only when the workflow explicitly schedules it (inherited child after IV-anchor FIXes are released).
- **IIV ESCALATION WORKFLOW (base-model screening, 1→2→3 cmt)**:
  - When escalating, FIRST ENABLE IIV on EVERY PK parameter, EXCEPT parameters whose IIV was already FIXED in the parent model.
  - 1-comp→2-comp: enable IIV on CL, V1, Q, V2; only inherit fixes that existed in the 1-comp parent.
  - 2-comp→3-comp: enable IIV on Q2, V2, Q3, V3; only inherit fixes that existed in the 2-comp parent.
  - After the run, for each newly-enabled IIV: if RSE% > 50%, FIX it — but first check (i) model change (ΔOFV) and (ii) numerical stability (singular covariance / rounding). Only fix when RSE>50% shows it is unreliable or it causes instability.
  - **CENTRAL → PERIPHERAL IIV CHAIN (HARD)**: if a CENTRAL parameter's IIV was FIXED in the parent, its peripheral relatives MUST also stay fixed (they cannot be estimated reliably):
    • CL IIV fixed → Q (2-cmt), Q2 and Q3 (3-cmt) IIV stay FIXED.
    • V / V1 IIV fixed → V2 (2-cmt), V3 (3-cmt) IIV stay FIXED.
    Example: if the 1-comp model had the distribution volume V IIV fixed, then in 3-cmt do NOT unfix V3 (estimation would be unreliable). CL follows the same rule.

## ADVAN/TRANS Reference (Complete NONMEM Mapping)

| ADVAN | TRANS | Compartments | Use | Dep. | Central | Periph-1 | Periph-2 | Periph-3 |
|-------|-------|-------------|-----|------|---------|----------|----------|----------|
| ADVAN1 | TRANS2 | 1 cmt | IV bolus/infusion | — | CMT=1 | — | — | — |
| ADVAN2 | TRANS2 | 1 cmt dep. + central | Oral/extravascular | CMT=1 | CMT=2 (S2) | — | — | — |
| ADVAN3 | TRANSS4 | 2 cmt central + periph | IV bolus/infusion | — | CMT=1 | CMT=2 | — | — |
| ADVAN4 | TRANSS4 | 3 cmt dep. + central + periph | Oral/extravascular | CMT=1 | CMT=2 (S2) | CMT=3 | — | — |
| ADVAN5 | TRANS1 | 1 cmt general linear | Rare; general linear | — | CMT=1 | — | — | — |
| ADVAN6 | TRANS1 | 2 cmt general linear | Rare; general linear | — | CMT=1 | CMT=2 | — | — |
| ADVAN7 | TRANS1 | 3 cmt general linear | Rare; general linear | — | CMT=1 | CMT=2 | CMT=3 | — |
| ADVAN8 | TRANSS1 | 1 cmt mix. mic. | Nonlinear (MM elimination) | — | CMT=1 | — | — | — |
| ADVAN9 | TRANSS1 | 1 cmt dep.+1 cmt | Oral/extravascular MM | CMT=1 | CMT=2 (S2) | — | — | — |
| ADVAN10 | TRANSS1 | 1 cmt | MM elimination only | — | CMT=1 | — | — | — |
| ADVAN11 | TRANSS4 | 3 cmt cent.+periph1+periph2 | IV 3-cmt | — | CMT=1 | CMT=2 | CMT=3 | — |
| ADVAN12 | TRANSS4 | 4 cmt dep.+cent.+2 periph | Oral 3-cmt | CMT=1 | CMT=2 (S2) | CMT=3 | CMT=4 | — |
| ADVAN13 | TRANSS1 | User-defined ODEs | Custom/explicit ODEs | — | — | — | — | — |

For mixed IV infusion + SC/extravascular data, first-order SC dosing to depot CMT=1 must NOT
receive D1 just because DUR exists in the dataset. IV infusion delivered directly to central
CMT=2 should use D2=DUR with a tiny positive fallback. SC zero-order absorption requires an
explicit depot-input implementation, not D1 bolted onto a first-order KA model.

## Parameter Naming Convention (STRICT)

| ADVAN | Parameters in $PK | $TABLE PATAB must list |
|-------|-------------------|----------------------|
| ADVAN1 | CL, V (V1=V) | CL, V |
| ADVAN2 | KA, CL, V (V1=V) | KA, CL, V |
| ADVAN3 | CL, V1, Q, V2 | CL, V1, Q, V2 |
| ADVAN4 | KA, CL, V2, Q, V3 | KA, CL, V2, Q, V3 |
| ADVAN11 | CL, V1, Q2, V2, Q3, V3 | CL, V1, Q2, V2, Q3, V3 |
| ADVAN12 | KA, CL, V2, Q3, V3, Q4, V4 | KA, CL, V2, Q3, V3, Q4, V4 |
| ADVAN8/10 | VMAX, KM, V | VMAX, KM, V |
| ADVAN13 | User-defined (list every THETA/ETA param) | Match $PK exactly |

**Rule**: $TABLE PATAB items **MUST exactly equal** the parameters declared in $PK. Check each parameter: if $PK has `CL, V1, Q2, V2, Q3, V3`, then PATAB has `CL V1 Q2 V2 Q3 V3`. If $PK has only `CL, V`, then PATAB has only `CL V`. Never add phantom Q/V2/KA for simpler models.

## Control Stream Block Contract

| Block | Purpose | AutoPMX writing rule |
| --- | --- | --- |
| `$PROBLEM` | Model identity | Include run ID, route, structure, one intended change from parent. |
| `$INPUT` | CSV→NONMEM mapping | Exact CSV header order. |
| `$DATA` | Dataset and row filter | `$DATA <dataset.csv> IGNORE=C` unless changed. |
| `$SUBROUTINES` | PREDPP solver | Use library templates. ADVAN1/2 for 1-cmt, ADVAN3/4 for 2-cmt, ADVAN11/12 for 3-cmt, ADVAN13 for ODEs. |
| `$MODEL` | Compartments (ADVAN13 only) | Must match $PK S1/S2 definitions. |
| `$DES` | ODE equations (ADVAN13 only) | DADT for every compartment in $MODEL. |
| `$PK` | Parameters, IIV, covariates, dosing, scaling | Set Q=0, V2=0, KA=0 for unused params in simpler models to keep TABLE safe. |
| `$ERROR` | Residual error | IPRED=F, W=combined prop+add, Y, IRES, IWRES. |
| `$THETA` | Fixed-effects | Count must match references. **Structural escalation initial values (CRITICAL for convergence):** When escalating 1-cmt→2-cmt, set peripheral V2≈0.3-0.5×V1 and Q≈0.5-0.8×CL. When escalating 2-cmt→3-cmt, set V3≈0.3-0.5×V1 and Q3≈0.3-0.6×CL. The rationale: the peripheral compartments should start small (rapid equilibrium) so the model is a gentle perturbation from the simpler parent. Starting with large peripheral volumes or high inter-compartment clearances causes immediate minimization failure. MAb typical initials: CL≈0.2-0.5 L/day (0.008-0.02 L/h), V≈3-6 L, Q≈0.3-1 L/day, V2/V3≈2-5 L, KA≈0.2-1 h⁻¹. |
| `$OMEGA` | ETA variances | Dimensions must match ETA references. Values are variances, not SDs. |
| `$SIGMA` | EPS scale | 1 FIX; residual SDs as THETA. |
| `$EST` | Estimation | METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10. |
| `$COV` | Covariance | PRINT=E MATRIX=S. |
| `$TABLE` | Output | Each item must be in $PK or be a NONMEM built-in. PATAB must mirror $PK exactly. |

## Template Selection

| Route | Initial | Structural Escalation | 3-cmt / Advanced |
|-------|---------|----------------------|-------------------|
| IV bolus, CMT=1 | `iv_bolus_1c_advan1_trans2` | `iv_bolus_2c_advan3_trans4` | `iv_bolus_3c_advan11_trans4` |
| IV infusion, DUR>0 or RATE>0 | `iv_infusion_1c_advan1_trans2` | `iv_infusion_2c_advan3_trans4` | `iv_infusion_3c_advan11_trans4` |
| Oral/extravascular | `extravascular_1c_advan2_trans2` | `extravascular_2c_advan4_trans4` | `extravascular_3c_advan12_trans4` |
| Mixed/nonstandard CMT | Nearest ADVAN template | `custom_linear_1c_des` | `custom_linear_2c_des` / `custom_linear_3c_des` |
| Nonlinear (Michaelis-Menten) | `iv_mm_advan10_trans1` | — | — |
| TMDD (full mechanistic) | `iv_tmdd_advan13` | — | — |

### Nonlinear PK Escalation Path

1. Start with linear IV infusion model (`iv_infusion_1c_advan1_trans2`)
2. If GOF shows dose-dependent clearance or non-linear concentration-time profiles:
   - Escalate to Michaelis-Menten (`iv_mm_advan10_trans1`) as a simpler approximation
   - If MM doesn't capture the nonlinearity, escalate to full TMDD (`iv_tmdd_advan13`)
3. TMDD detection criteria: dose range >10x, dose-normalized AUC decreases with dose

## Parameter Naming Convention (Updated for 3-cmt and TMDD)

| ADVAN | Parameters in $PK | $TABLE PATAB must list |
|-------|-------------------|----------------------|
| ADVAN11 | CL, V1, Q2, V2, Q3, V3 | CL V1 Q2 V2 Q3 V3 |
| ADVAN10 | VMAX, KM, V | VMAX KM V |
| ADVAN13 (TMDD) | CL, V1, Q, V2, KINT, KON, KOFF, R0 | CL V1 Q V2 KINT KON KOFF R0 |

## Writing Speed Directive

When DuDu PMx drafts a control stream:
1. **DETECT** route from data → pick the matching template below
2. **FILL** placeholders: {RUN}, {INPUT_RECORD}, {DATA_FILE}, {WT_MEDIAN}
3. **VERIFY** that $TABLE PATAB matches $PK parameters exactly — every parameter in PATAB must exist in $PK
4. **CHECK** nonlinear PK: if dose range >10x, flag for TMDD escalation after initial linear fit
5. **RETURN** the file — do not explain unless asked

## Complete Template Catalog (COPY directly, only change {RUN} and initial estimates)

These templates have been verified with PsN 5.7 + NONMEM. Copy the exact block structure.
DO NOT add $IRES or $IWRES — PsN 5.7 does not support them and will fail.
DO nest IRES/IWRES inside $ERROR using IRES=F-Y; IWRES=(F-Y)/W instead of separate records.

### iv_infusion_1c_advan1_trans2 (IV Infusion 1-cmt — START HERE for IV infusion data)

```
$PROBLEM Run{RUN}: IV infusion 1-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN1 TRANS2
$PK
IF (DUR.GT.0) D1=DUR
IF (DUR.LE.0) D1=0.0001
TVCL=THETA(1)
TVV=THETA(2)
CL=TVCL*EXP(ETA(1))
V=TVV*EXP(ETA(2))
S1=V/1000
$ERROR
IPRED=F
W=SQRT((THETA(3)*IPRED)**2 + THETA(4)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/day)
(0, 4.0) ; V (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### iv_infusion_2c_advan3_trans4 (IV Infusion 2-cmt — escalate when 1-cmt GOF shows biphasic decline)

```
$PROBLEM Run{RUN}: IV infusion 2-cmt model (added Q, V2)
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN3 TRANS4
$PK
IF (DUR.GT.0) D1=DUR
IF (DUR.LE.0) D1=0.0001
TVCL=THETA(1)
TVV1=THETA(2)
TVQ=THETA(3)
TVV2=THETA(4)
CL=TVCL*EXP(ETA(1))
V1=TVV1*EXP(ETA(2))
Q=TVQ*EXP(ETA(3))
V2=TVV2*EXP(ETA(4))
S1=V1/1000
$ERROR
IPRED=F
W=SQRT((THETA(5)*IPRED)**2 + THETA(6)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/day)
(0, 4.0) ; V1 (L)
(0, 0.5) ; Q (L/day)
(0, 3.0) ; V2 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V1 Q V2 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V1 Q V2 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V1 Q V2 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### iv_infusion_3c_advan11_trans4 (IV Infusion 3-cmt — escalate when 2-cmt still shows misspecification)

```
$PROBLEM Run{RUN}: IV infusion 3-cmt model (added Q3, V3)
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN11 TRANS4
$PK
IF (DUR.GT.0) D1=DUR
IF (DUR.LE.0) D1=0.0001
TVCL=THETA(1)
TVV1=THETA(2)
TVQ2=THETA(3)
TVV2=THETA(4)
TVQ3=THETA(5)
TVV3=THETA(6)
CL=TVCL*EXP(ETA(1))
V1=TVV1*EXP(ETA(2))
Q2=TVQ2*EXP(ETA(3))
V2=TVV2*EXP(ETA(4))
Q3=TVQ3*EXP(ETA(5))
V3=TVV3*EXP(ETA(6))
S1=V1/1000
$ERROR
IPRED=F
W=SQRT((THETA(7)*IPRED)**2 + THETA(8)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/day)
(0, 4.0) ; V1 (L)
(0, 0.5) ; Q2 (L/day)
(0, 3.0) ; V2 (L)
(0, 0.3) ; Q3 (L/day)
(0, 5.0) ; V3 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q2
0.04 ; IIV V2
0.04 ; IIV Q3
0.04 ; IIV V3
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### iv_bolus_1c_advan1_trans2 (IV Bolus 1-cmt)

```
$PROBLEM Run{RUN}: IV bolus 1-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN1 TRANS2
$PK
TVCL=THETA(1)
TVV=THETA(2)
CL=TVCL*EXP(ETA(1))
V=TVV*EXP(ETA(2))
S1=V/1000
$ERROR
IPRED=F
W=SQRT((THETA(3)*IPRED)**2 + THETA(4)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### extravascular_1c_advan2_trans2 (Oral/Extravascular 1-cmt dep.)

```
$PROBLEM Run{RUN}: Extravascular 1-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN2 TRANS2
$PK
TVKA=THETA(1)
TVCL=THETA(2)
TVV=THETA(3)
KA=TVKA*EXP(ETA(1))
CL=TVCL*EXP(ETA(2))
V=TVV*EXP(ETA(3))
S2=V/1000
$ERROR
IPRED=F
W=SQRT((THETA(4)*IPRED)**2 + THETA(5)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.5) ; KA (1/hr)
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV KA
0.09 ; IIV CL
0.05 ; IIV V
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID KA CL V ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID KA CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID KA CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### iv_bolus_2c_advan3_trans4 (IV Bolus 2-cmt)

```
$PROBLEM Run{RUN}: IV bolus 2-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN3 TRANS4
$PK
TVCL=THETA(1)
TVV1=THETA(2)
TVQ=THETA(3)
TVV2=THETA(4)
CL=TVCL*EXP(ETA(1))
V1=TVV1*EXP(ETA(2))
Q=TVQ*EXP(ETA(3))
V2=TVV2*EXP(ETA(4))
S1=V1/1000
$ERROR
IPRED=F
W=SQRT((THETA(5)*IPRED)**2 + THETA(6)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V1 (L)
(0, 0.5) ; Q (L/hr)
(0, 3.0) ; V2 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V1 Q V2 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V1 Q V2 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V1 Q V2 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### iv_bolus_3c_advan11_trans4 (IV Bolus 3-cmt)

```
$PROBLEM Run{RUN}: IV bolus 3-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN11 TRANS4
$PK
TVCL=THETA(1)
TVV1=THETA(2)
TVQ2=THETA(3)
TVV2=THETA(4)
TVQ3=THETA(5)
TVV3=THETA(6)
CL=TVCL*EXP(ETA(1))
V1=TVV1*EXP(ETA(2))
Q2=TVQ2*EXP(ETA(3))
V2=TVV2*EXP(ETA(4))
Q3=TVQ3*EXP(ETA(5))
V3=TVV3*EXP(ETA(6))
S1=V1/1000
$ERROR
IPRED=F
W=SQRT((THETA(7)*IPRED)**2 + THETA(8)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V1 (L)
(0, 0.5) ; Q2 (L/hr)
(0, 3.0) ; V2 (L)
(0, 0.3) ; Q3 (L/hr)
(0, 5.0) ; V3 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q2
0.04 ; IIV V2
0.04 ; IIV Q3
0.04 ; IIV V3
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID CL V1 Q2 V2 Q3 V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### extravascular_2c_advan4_trans4 (Oral/Extravascular 2-cmt dep.)

```
$PROBLEM Run{RUN}: Extravascular 2-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN4 TRANS4
$PK
TVKA=THETA(1)
TVCL=THETA(2)
TVV2=THETA(3)
TVQ=THETA(4)
TVV3=THETA(5)
KA=TVKA*EXP(ETA(1))
CL=TVCL*EXP(ETA(2))
V2=TVV2*EXP(ETA(3))
Q=TVQ*EXP(ETA(4))
V3=TVV3*EXP(ETA(5))
S2=V2/1000
$ERROR
IPRED=F
W=SQRT((THETA(6)*IPRED)**2 + THETA(7)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.5) ; KA (1/hr)
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V2 (L)
(0, 0.5) ; Q (L/hr)
(0, 3.0) ; V3 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV KA
0.09 ; IIV CL
0.05 ; IIV V2
0.04 ; IIV Q
0.04 ; IIV V3
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID KA CL V2 Q V3 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID KA CL V2 Q V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID KA CL V2 Q V3 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```

### extravascular_3c_advan12_trans4 (Oral/Extravascular 3-cmt dep.)

```
$PROBLEM Run{RUN}: Extravascular 3-cmt model
$INPUT {INPUT_RECORD}
$DATA {DATA_FILE} IGNORE=C
$SUBROUTINES ADVAN12 TRANS4
$PK
TVKA=THETA(1)
TVCL=THETA(2)
TVV2=THETA(3)
TVQ3=THETA(4)
TVV3=THETA(5)
TVQ4=THETA(6)
TVV4=THETA(7)
KA=TVKA*EXP(ETA(1))
CL=TVCL*EXP(ETA(2))
V2=TVV2*EXP(ETA(3))
Q3=TVQ3*EXP(ETA(4))
V3=TVV3*EXP(ETA(5))
Q4=TVQ4*EXP(ETA(6))
V4=TVV4*EXP(ETA(7))
S2=V2/1000
$ERROR
IPRED=F
W=SQRT((THETA(8)*IPRED)**2 + THETA(9)**2)
Y=IPRED+W*EPS(1)
IRES=F-Y
IWRES=(F-Y)/W
$THETA
(0, 0.5) ; KA (1/hr)
(0, 0.2) ; CL (L/hr)
(0, 5.0) ; V2 (L)
(0, 0.5) ; Q3 (L/hr)
(0, 3.0) ; V3 (L)
(0, 0.3) ; Q4 (L/hr)
(0, 5.0) ; V4 (L)
(0, 0.15) ; Prop.RE (sd)
(0, 1.0) ; Add.RE (sd)
$OMEGA
0.08 ; IIV KA
0.09 ; IIV CL
0.05 ; IIV V2
0.04 ; IIV Q3
0.04 ; IIV V3
0.04 ; IIV Q4
0.04 ; IIV V4
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <project $INPUT columns excluding C> ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID KA CL V2 Q3 V3 Q4 V4 ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID KA CL V2 Q3 V3 Q4 V4 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID KA CL V2 Q3 V3 Q4 V4 FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```
