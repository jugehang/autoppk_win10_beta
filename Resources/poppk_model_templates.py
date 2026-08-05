#!/usr/bin/env python3
"""Reusable NONMEM PopPK control-stream templates for AutoPMX.

The Swift app gives this library to local LLMs as a syntax anchor, and this
module can also render a deterministic starting model when a full LLM draft is
too brittle.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional


DEFAULT_INPUT_COLUMNS = [
    "C",
    "ID",
    "CYCLE",
    "DAY",
    "TIME",
    "NTIME",
    "DV",
    "AMT",
    "RATE",
    "DUR",
    "CMT",
    "DOSE",
    "MDV",
    "EVID",
    "BQL",
    "TYPE",
    "STUDY",
    "SEX",
    "WT",
    "AGE",
]


@dataclass(frozen=True)
class TemplateSpec:
    template_id: str
    title: str
    route: str
    subroutine: str
    body: str


def _tables(
    run: str,
    pk_params: list[str],
    eta_terms: str,
    cat_cols: list[str] | tuple[str, ...] = ("SEX", "STUDY", "ADA"),
    cont_cols: list[str] | tuple[str, ...] = ("WT", "AGE", "DOSE"),
) -> str:
    param_tokens = " ".join(pk_params) if pk_params else "CL V"
    cat_tokens = " ".join(cat_cols) if cat_cols else "ID"
    cont_tokens = " ".join(cont_cols) if cont_cols else "ID"
    return f"""$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=SDTAB{run} FORMAT=s1PE14.7
$TABLE ID {param_tokens} {eta_terms} NOPRINT NOAPPEND ONEHEADER FILE=PATAB{run}
$TABLE ID {eta_terms} FIRSTONLY NOAPPEND NOPRINT FILE=run{run}.ETA
$TABLE ID {cat_tokens} NOPRINT NOAPPEND ONEHEADER FILE=CATAB{run}
$TABLE ID {cont_tokens} NOPRINT NOAPPEND ONEHEADER FILE=COTAB{run}"""


def normalize_input_columns(input_columns: Optional[Iterable[str]] = None) -> list[str]:
    """Normalize AutoPMX `$INPUT` tokens without changing CSV column order.

    AutoPMX datasets use `$DATA ... IGNORE=C`; therefore `C` is not an
    unused modeling covariate. It must remain in `$INPUT` as plain `C`.
    The input order must mirror the CSV header order exactly. The default
    AutoPMX CSV has `C` as the first column.
    """

    columns = list(input_columns or DEFAULT_INPUT_COLUMNS)
    normalized: list[str] = []
    found_c = False
    for column in columns:
        stripped = str(column).strip().strip(",")
        if not stripped:
            continue
        name = stripped.split("=", 1)[0].upper()
        if name == "C":
            if not found_c:
                normalized.append("C")
                found_c = True
            continue
        normalized.append(stripped)
    if not found_c:
        normalized.insert(0, "C")
    return normalized


COMMON_ESTIMATION = """$EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
$COVARIANCE PRINT=E MATRIX=S"""


TEMPLATES: Dict[str, TemplateSpec] = {
    "iv_bolus_1c_advan1_trans2": TemplateSpec(
        template_id="iv_bolus_1c_advan1_trans2",
        title="IV bolus 1-compartment ADVAN1 TRANS2",
        route="iv_bolus",
        subroutine="ADVAN1 TRANS2",
        body="""$SUBROUTINES ADVAN1 TRANS2

$PK
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V = TVV1 * EXP(ETA(2))
V1 = V
Q = 0
V2 = 0
KA = 0
S1 = V/1000

$ERROR
IPRED = F
W = SQRT((THETA(3)*IPRED)**2 + THETA(4)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_infusion_1c_advan1_trans2": TemplateSpec(
        template_id="iv_infusion_1c_advan1_trans2",
        title="IV infusion 1-compartment ADVAN1 TRANS2",
        route="iv_infusion",
        subroutine="ADVAN1 TRANS2",
        body="""$SUBROUTINES ADVAN1 TRANS2

$PK
D1 = MAX(DUR, 0.0001)
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V = TVV1 * EXP(ETA(2))
V1 = V
Q = 0
V2 = 0
KA = 0
S1 = V/1000

$ERROR
IPRED = F
W = SQRT((THETA(3)*IPRED)**2 + THETA(4)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_bolus_2c_advan3_trans4": TemplateSpec(
        template_id="iv_bolus_2c_advan3_trans4",
        title="IV bolus 2-compartment ADVAN3 TRANS4",
        route="iv_bolus",
        subroutine="ADVAN3 TRANS4",
        body="""$SUBROUTINES ADVAN3 TRANS4

$PK
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ = THETA(3)
Q = TVQ * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
KA = 0
S1 = V1/1000

$ERROR
IPRED = F
W = SQRT((THETA(5)*IPRED)**2 + THETA(6)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q_L/h
(0, 2.0, 50) ; V2_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_infusion_2c_advan3_trans4": TemplateSpec(
        template_id="iv_infusion_2c_advan3_trans4",
        title="IV infusion 2-compartment ADVAN3 TRANS4",
        route="iv_infusion",
        subroutine="ADVAN3 TRANS4",
        body="""$SUBROUTINES ADVAN3 TRANS4

$PK
D1 = MAX(DUR, 0.0001)
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ = THETA(3)
Q = TVQ * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
KA = 0
S1 = V1/1000

$ERROR
IPRED = F
W = SQRT((THETA(5)*IPRED)**2 + THETA(6)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q_L/h
(0, 2.0, 50) ; V2_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "extravascular_1c_advan2_trans2": TemplateSpec(
        template_id="extravascular_1c_advan2_trans2",
        title="Extravascular 1-compartment ADVAN2 TRANS2",
        route="extravascular",
        subroutine="ADVAN2 TRANS2",
        body="""$SUBROUTINES ADVAN2 TRANS2

$PK
TVKA = THETA(1)
KA = TVKA * EXP(ETA(1))
TVCL = THETA(2)
CL = TVCL * EXP(ETA(2))
TVV1 = THETA(3)
V = TVV1 * EXP(ETA(3))
V1 = V
Q = 0
V2 = 0
S2 = V/1000

$ERROR
IPRED = F
W = SQRT((THETA(4)*IPRED)**2 + THETA(5)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.2, 10) ; KA_1/h
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV KA
0.09 ; IIV CL
0.09 ; IIV V1

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "extravascular_2c_advan4_trans4": TemplateSpec(
        template_id="extravascular_2c_advan4_trans4",
        title="Extravascular 2-compartment ADVAN4 TRANS4",
        route="extravascular",
        subroutine="ADVAN4 TRANS4",
        body="""$SUBROUTINES ADVAN4 TRANS4

$PK
TVKA = THETA(1)
KA = TVKA * EXP(ETA(1))
TVCL = THETA(2)
CL = TVCL * EXP(ETA(2))
TVV1 = THETA(3)
V2 = TVV1 * EXP(ETA(3))
V1 = V2
TVQ = THETA(4)
Q = TVQ * EXP(ETA(4))
TVVPER = THETA(5)
V3 = TVVPER * EXP(ETA(5))
VPER = V3
S2 = V2/1000

$ERROR
IPRED = F
W = SQRT((THETA(6)*IPRED)**2 + THETA(7)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.2, 10) ; KA_1/h
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q_L/h
(0, 2.0, 50) ; V2_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV KA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "custom_linear_1c_des": TemplateSpec(
        template_id="custom_linear_1c_des",
        title="Custom linear 1-compartment DES",
        route="custom",
        subroutine="ADVAN13 TOL=6",
        body="""$SUBROUTINES ADVAN13 TOL=6
$MODEL COMP=(CENTRAL)

$PK
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
Q = 0
V2 = 0
KA = 0
S1 = V1/1000

$DES
DADT(1) = -(CL/V1)*A(1)

$ERROR
IPRED = F
W = SQRT((THETA(3)*IPRED)**2 + THETA(4)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "custom_linear_2c_des": TemplateSpec(
        template_id="custom_linear_2c_des",
        title="Custom linear 2-compartment DES",
        route="custom",
        subroutine="ADVAN13 TOL=6",
        body="""$SUBROUTINES ADVAN13 TOL=6
$MODEL COMP=(CENTRAL) COMP=(PERIPH)

$PK
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ = THETA(3)
Q = TVQ * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
KA = 0
S1 = V1/1000

$DES
DADT(1) = -(CL/V1)*A(1) - (Q/V1)*A(1) + (Q/V2)*A(2)
DADT(2) =  (Q/V1)*A(1) - (Q/V2)*A(2)

$ERROR
IPRED = F
W = SQRT((THETA(5)*IPRED)**2 + THETA(6)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q_L/h
(0, 2.0, 50) ; V2_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_infusion_3c_advan11_trans4": TemplateSpec(
        template_id="iv_infusion_3c_advan11_trans4",
        title="IV infusion 3-compartment ADVAN11 TRANS4",
        route="iv_infusion",
        subroutine="ADVAN11 TRANS4",
        body="""$SUBROUTINES ADVAN11 TRANS4

$PK
D1 = MAX(DUR, 0.0001)
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ2 = THETA(3)
Q2 = TVQ2 * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
TVQ3 = THETA(5)
Q3 = TVQ3
TVV3 = THETA(6)
V3 = TVV3
KA = 0
S1 = V1/1000

$ERROR
IPRED = F
W = SQRT((THETA(7)*IPRED)**2 + THETA(8)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q2_L/h
(0, 2.0, 50) ; V2_L
(0, 0.005, 5) ; Q3_L/h
(0, 1.0, 30) ; V3_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q2
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_bolus_3c_advan11_trans4": TemplateSpec(
        template_id="iv_bolus_3c_advan11_trans4",
        title="IV bolus 3-compartment ADVAN11 TRANS4",
        route="iv_bolus",
        subroutine="ADVAN11 TRANS4",
        body="""$SUBROUTINES ADVAN11 TRANS4

$PK
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ2 = THETA(3)
Q2 = TVQ2 * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
TVQ3 = THETA(5)
Q3 = TVQ3
TVV3 = THETA(6)
V3 = TVV3
KA = 0
Q = 0
V = 0
S1 = V1/1000

$ERROR
IPRED = F
W = SQRT((THETA(7)*IPRED)**2 + THETA(8)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q2_L/h
(0, 2.0, 50) ; V2_L
(0, 0.005, 5) ; Q3_L/h
(0, 1.0, 30) ; V3_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q2
0.04 ; IIV V2

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_tmdd_advan13": TemplateSpec(
        template_id="iv_tmdd_advan13",
        title="IV TMDD (full) 2-compartment ADVAN13",
        route="iv_infusion",
        subroutine="ADVAN13 TOL=6",
        body="""$SUBROUTINES ADVAN13 TOL=6
$MODEL COMP=(CENTRAL) COMP=(PERIPH) COMP=(TARGET) COMP=(COMPLEX)

$PK
D1 = MAX(DUR, 0.0001)
TVCL = THETA(1)
CL = TVCL * EXP(ETA(1))
TVV1 = THETA(2)
V1 = TVV1 * EXP(ETA(2))
TVQ = THETA(3)
Q = TVQ * EXP(ETA(3))
TVV2 = THETA(4)
V2 = TVV2 * EXP(ETA(4))
TVKINT = THETA(5)
KINT = TVKINT
TVKON = THETA(6)
KON = TVKON
TVKOFF = THETA(7)
KOFF = TVKOFF
TVR0 = THETA(8)
R0 = TVR0 * EXP(ETA(5))
KA = 0
S1 = V1/1000
F1 = 1

$DES
; Free drug concentration in central
C1 = A(1)/V1
; Target in central (pre-formed, baseline R0)
; Complex formation and dissociation
DADT(1) = -(CL/V1)*A(1) - (Q/V1)*A(1) + (Q/V2)*A(2) - KON*C1*A(3) + KOFF*A(4)
DADT(2) =  (Q/V1)*A(1) - (Q/V2)*A(2)
DADT(3) = -KON*C1*A(3) + KOFF*A(4) - KINT*A(3) + (KINT*R0)
DADT(4) =  KON*C1*A(3) - KOFF*A(4) - KINT*A(4)

$ERROR
IPRED = A(1)/V1 + A(4)/V1
W = SQRT((THETA(9)*IPRED)**2 + THETA(10)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 0.012, 10) ; CL_L/h (nonspecific)
(0, 4.0, 50) ; V1_L
(0, 0.02, 10) ; Q_L/h
(0, 2.0, 50) ; V2_L
(0, 0.001, 1) ; KINT_1/h (internalization)
(0, 0.001, 10) ; KON_1/(ng/mL)/h
(0, 0.01, 10) ; KOFF_1/h
(0, 10, 1000) ; R0_ng/mL (baseline target)
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV CL
0.09 ; IIV V1
0.04 ; IIV Q
0.09 ; IIV R0

$SIGMA
1 FIX ; Residual error scale""",
    ),
    "iv_mm_advan10_trans1": TemplateSpec(
        template_id="iv_mm_advan10_trans1",
        title="IV Michaelis-Menten 1-compartment ADVAN10",
        route="iv_infusion",
        subroutine="ADVAN10 TRANS1",
        body="""$SUBROUTINES ADVAN10 TRANS1

$PK
D1 = MAX(DUR, 0.0001)
TVVMAX = THETA(1)
VMAX = TVVMAX * EXP(ETA(1))
TVKM = THETA(2)
KM = TVKM * EXP(ETA(2))
TVV = THETA(3)
V = TVV * EXP(ETA(3))
V1 = V
Q = 0
V2 = 0
KA = 0
S1 = V/1000

$ERROR
IPRED = F
W = SQRT((THETA(4)*IPRED)**2 + THETA(5)**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W

$THETA
(0, 10, 1000) ; VMAX_mg/L/h
(0, 100, 10000) ; KM_ng/mL
(0, 4.0, 50) ; V_L
(0, 0.20, 2) ; Prop.RE (sd)
(0, 0.01, 10) ; Add.RE (sd)

$OMEGA
0.09 ; IIV VMAX
0.09 ; IIV KM
0.09 ; IIV V

$SIGMA
1 FIX ; Residual error scale""",
    ),
}


def recommended_template_id(route: str, compartments: int = 1) -> str:
    normalized = route.strip().lower().replace(" ", "_")
    if normalized in {"iv_infusion", "infusion"}:
        if compartments >= 3:
            return "iv_infusion_3c_advan11_trans4"
        return "iv_infusion_2c_advan3_trans4" if compartments >= 2 else "iv_infusion_1c_advan1_trans2"
    if normalized in {"iv_bolus", "bolus"}:
        if compartments >= 3:
            return "iv_bolus_3c_advan11_trans4"
        return "iv_bolus_2c_advan3_trans4" if compartments >= 2 else "iv_bolus_1c_advan1_trans2"
    if normalized in {"oral", "extravascular", "ev"}:
        return "extravascular_2c_advan4_trans4" if compartments >= 2 else "extravascular_1c_advan2_trans2"
    if normalized in {"tmdd", "nonlinear"}:
        return "iv_tmdd_advan13"
    if normalized in {"michaelis_menten", "mm"}:
        return "iv_mm_advan10_trans1"
    if normalized in {"mixed", "custom"}:
        return "custom_linear_2c_des" if compartments >= 2 else "custom_linear_1c_des"
    return "iv_bolus_2c_advan3_trans4" if compartments >= 2 else "iv_bolus_1c_advan1_trans2"


# --- PK parameter extraction per template ---

_PK_PARAMS: Dict[str, list[str]] = {
    "iv_bolus_1c_advan1_trans2":     ["CL", "V"],
    "iv_infusion_1c_advan1_trans2":  ["CL", "V"],
    "iv_bolus_2c_advan3_trans4":     ["CL", "V1", "Q", "V2"],
    "iv_infusion_2c_advan3_trans4":  ["CL", "V1", "Q", "V2"],
    "extravascular_1c_advan2_trans2": ["KA", "CL", "V"],
    "extravascular_2c_advan4_trans4": ["KA", "CL", "V2", "Q", "V3"],
    "custom_linear_1c_des":          ["CL", "V1"],
    "custom_linear_2c_des":          ["CL", "V1", "Q", "V2"],
    "iv_infusion_3c_advan11_trans4": ["CL", "V1", "Q2", "V2", "Q3", "V3"],
    "iv_bolus_3c_advan11_trans4":    ["CL", "V1", "Q2", "V2", "Q3", "V3"],
    "iv_tmdd_advan13":               ["CL", "V1", "Q", "V2", "KINT", "KON", "KOFF", "R0"],
    "iv_mm_advan10_trans1":          ["VMAX", "KM", "V"],
}

def _get_pk_params(template_id: str) -> list[str]:
    return _PK_PARAMS.get(template_id, ["CL", "V"])


def render_model(
    template_id: str,
    run_id: str,
    data_file: str = "NM_dat_new.csv",
    input_columns: Optional[Iterable[str]] = None,
    problem: Optional[str] = None,
) -> str:
    spec = TEMPLATES[template_id]
    run = str(run_id).zfill(3) if str(run_id).isdigit() and len(str(run_id)) <= 3 else str(run_id)
    normalized_columns = normalize_input_columns(input_columns)
    input_record = " ".join(normalized_columns)
    cat_cols = [c for c in ("SEX", "STUDY", "ADA", "ROUTE", "BQL", "TYPE", "CMT", "EVID", "MDV")
                if c in normalized_columns] or ["STUDY", "SEX"]
    cont_cols = [c for c in ("WT", "AGE", "DOSE", "AMT", "RATE", "DUR")
                 if c in normalized_columns] or ["WT", "AGE"]
    max_eta = max([int(value) for value in re.findall(r"\bETA\((\d+)\)", spec.body)] or [0])
    eta_terms = " ".join(f"ETA{index}" for index in range(1, max_eta + 1))
    title = problem or f"AutoPMX run{run} - {spec.title}"
    return "\n\n".join(
        [
            f"$PROBLEM {title}",
            f"$INPUT {input_record}",
            f"$DATA {data_file} IGNORE=C",
            spec.body,
            COMMON_ESTIMATION,
            _tables(run, _get_pk_params(template_id), eta_terms, cat_cols, cont_cols),
            "",
        ]
    )


def load_library_markdown(path: Optional[Path] = None) -> str:
    target = path or Path(__file__).with_name("poppk_model_library.md")
    return target.read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Render an AutoPMX NONMEM template")
    parser.add_argument("template", choices=sorted(TEMPLATES))
    parser.add_argument("--run", default="001")
    parser.add_argument("--data", default="NM_dat_new.csv")
    parser.add_argument("--output")
    args = parser.parse_args()

    rendered = render_model(args.template, args.run, args.data)
    if args.output:
        Path(args.output).write_text(rendered, encoding="utf-8")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
