# AutoPMX PopPK NONMEM Model Library

This library is the syntax anchor for DuDu PMx automated model building. Local LLMs should NOT draft NONMEM control streams from memory. They should choose the closest template below, fill the placeholders, and only make focused edits supported by diagnostics.

## Global Rules

- Always start automated model building with the simplest defensible structural model for the detected route.
- Prefer library templates over free-form NONMEM syntax.
- Keep `$DATA {DATA_FILE} IGNORE=C` unless the user explicitly changes the dataset/comment flag.
- Treat the CSV header as the source of truth for `$INPUT`: labels must appear in the same order as the data file columns.
- The `C` column must remain a literal `C` token and must never be written as `C=DROP`, `C=SKIP`, omitted, or moved away from its CSV position.
- Use semicolon labels on `$THETA`, `$OMEGA`, and `$SIGMA`; the parameter extraction pipeline relies on these labels.
- Default residual error is combined proportional plus additive.
- Use `S1=V/1000` for IV central observations in compartment 1, and `S2=V/1000` for extravascular models where central observations are in compartment 2. S1/S2 MUST always be the LAST line of $PK — the variables they reference (V, V1, V2) must be defined first.
- Keep `$EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10` and `$COV UNCONDITIONAL`.
- Keep generated run IDs consistent in all table filenames.

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
| `$DATA` | Dataset and row filter | `$DATA NM_dat_new.csv IGNORE=C` unless changed. |
| `$SUBROUTINES` | PREDPP solver | Use library templates. ADVAN1/2 for 1-cmt, ADVAN3/4 for 2-cmt, ADVAN11/12 for 3-cmt, ADVAN13 for ODEs. |
| `$MODEL` | Compartments (ADVAN13 only) | Must match $PK S1/S2 definitions. |
| `$DES` | ODE equations (ADVAN13 only) | DADT for every compartment in $MODEL. |
| `$PK` | Parameters, IIV, covariates, dosing, scaling | Set Q=0, V2=0, KA=0 for unused params in simpler models to keep TABLE safe. |
| `$ERROR` | Residual error | IPRED=F, W=combined prop+add, Y, IRES, IWRES. |
| `$THETA` | Fixed-effects | Count must match references. **Structural escalation initial values (CRITICAL for convergence):** When escalating 1-cmt→2-cmt, set peripheral V2≈0.3-0.5×V1 and Q≈0.5-0.8×CL. When escalating 2-cmt→3-cmt, set V3≈0.3-0.5×V1 and Q3≈0.3-0.6×CL. The rationale: the peripheral compartments should start small (rapid equilibrium) so the model is a gentle perturbation from the simpler parent. Starting with large peripheral volumes or high inter-compartment clearances causes immediate minimization failure. MAb typical initials: CL≈0.2-0.5 L/day (0.008-0.02 L/h), V≈3-6 L, Q≈0.3-1 L/day, V2/V3≈2-5 L, KA≈0.2-1 h⁻¹. |
| `$OMEGA` | ETA variances | Dimensions must match ETA references. Values are variances, not SDs. |
| `$SIGMA` | EPS scale | 1 FIX; residual SDs as THETA. |
| `$EST` | Estimation | METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10. |
| `$COV` | Covariance | UNCONDITIONAL. |
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
CLTV=THETA(1)
VTV=THETA(2)
CL=CLTV*EXP(ETA(1))
V=VTV*EXP(ETA(2))
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
$COVARIANCE UNCONDITIONAL
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
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
CLTV=THETA(1)
V1TV=THETA(2)
QTV=THETA(3)
V2TV=THETA(4)
CL=CLTV*EXP(ETA(1))
V1=V1TV*EXP(ETA(2))
Q=QTV
V2=V2TV
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
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE UNCONDITIONAL
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
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
CLTV=THETA(1)
V1TV=THETA(2)
Q2TV=THETA(3)
V2TV=THETA(4)
Q3TV=THETA(5)
V3TV=THETA(6)
CL=CLTV*EXP(ETA(1))
V1=V1TV*EXP(ETA(2))
Q2=Q2TV
V2=V2TV
Q3=Q3TV
V3=V3TV
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
$SIGMA
1 FIX
$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE UNCONDITIONAL
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
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
CLTV=THETA(1)
VTV=THETA(2)
CL=CLTV*EXP(ETA(1))
V=VTV*EXP(ETA(2))
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
$COVARIANCE UNCONDITIONAL
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
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
KATV=THETA(1)
CLTV=THETA(2)
VTV=THETA(3)
KA=KATV*EXP(ETA(1))
CL=CLTV*EXP(ETA(2))
V=VTV*EXP(ETA(3))
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
$COVARIANCE UNCONDITIONAL
$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab{RUN}
$TABLE ID KA CL V ONEHEADER NOPRINT NOAPPEND FILE=patab{RUN}
$TABLE ID KA CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{RUN}
$TABLE ID KA CL V FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{RUN}
```
