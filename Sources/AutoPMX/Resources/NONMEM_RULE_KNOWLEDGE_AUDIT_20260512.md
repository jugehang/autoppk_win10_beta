# AutoPMX NONMEM Rule & Knowledge Library Audit

Date: 2026-05-12

Scope reviewed:

- `PopPK_Agent/poppk_rules.json`
- `PopPK_Agent/poppk_model_library.md`
- `PopPK_Agent/poppk_model_templates.py`
- `project_config.json`
- Current automation expectations in the macOS app and Python task layer

External references checked:

- NONMEM Documentation, `$INPUT`: https://nmusers.github.io/docs/reference-manual/control-records/input/
- NONMEM Documentation, `$DATA`: https://nmusers.github.io/docs/reference-manual/control-records/data/
- NONMEM Documentation, data/event records: https://nmusers.github.io/docs/user-guide/nmtran/data/
- NONMEM Documentation, `$ESTIMATION`: https://nmusers.github.io/docs/reference-manual/control-records/estimation/
- NONMEM Documentation, `$OMEGA`: https://nmusers.github.io/docs/reference-manual/control-records/omega/
- NONMEM Documentation, `$SIGMA`: https://nmusers.github.io/docs/reference-manual/control-records/sigma/
- NONMEM Documentation, `$TABLE`: https://nmusers.github.io/docs/reference-manual/control-records/table/
- FDA Population Pharmacokinetics Guidance for Industry, February 2022: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/population-pharmacokinetics
- EMA Guideline on reporting population PK analyses: https://www.ema.europa.eu/en/reporting-results-population-pharmacokinetic-analyses-scientific-guideline
- PsN documentation home: https://uupharmacometrics.github.io/PsN/

## Executive Summary

The current AutoPMX rule library is a strong first layer for regulatory framing, basic NONMEM control-stream structure, GOF/VPC/bootstrap/SCM, covariates, mAb biology, and reporting. It currently contains 49 rules across 8 namespaces:

- `@Regulatory`: 6
- `@BioPhys`: 4
- `@ModelingTechniques`: 13
- `@DataStandards`: 4
- `@ModelEvaluation`: 7
- `@CovariateAnalysis`: 4
- `@mAb_EarlyClinical`: 6
- `@Reporting`: 5

The largest gap is that many rules are conceptual rather than executable. For LLM-driven model writing, AutoPMX needs more machine-checkable rules for NONMEM syntax, data semantics, PREDPP/ADVAN choices, estimation method selection, BLQ/BQL handling, and final-model acceptance checks.

## Coverage That Looks Good

1. Core control-stream records are represented: `$PROBLEM`, `$INPUT`, `$DATA`, `$SUBROUTINES`, `$PK`, `$ERROR`, `$THETA`, `$OMEGA`, `$SIGMA`, `$ESTIMATION`, `$TABLE`.
2. Regulatory model-development lifecycle is present: preliminary data exploration, iterative model development, validation, reporting.
3. Main model-evaluation concepts are present: GOF, residuals, VPC, bootstrap, OFV, eta shrinkage.
4. Covariate workflow is present: SCM, continuous/categorical relationships, clinical relevance.
5. mAb-specific biology is present: nonspecific clearance, FcRn, TMDD, IgG subtype, ADA, exposure-response.
6. The new `poppk_model_library.md` now gives reusable template skeletons for IV bolus, IV infusion, extravascular, and custom DES models.

## High-Priority Gaps

### 1. `$INPUT` / `$DATA` Rules Need More Detail

Current library has generic `$INPUT` and `$DATA` rules plus the newly added `C` rule. Missing:

- Reserved labels and labels that should not appear in `$INPUT`, such as ETA labels and PK parameter labels.
- DROP/SKIP equivalence and the fact that dropped items do not appear in the NONMEM data set.
- Multiple `$INPUT` records continuing previous `$INPUT` records.
- DATE/DAT1/DAT2/DAT3 and TIME conversion rules.
- `$DATA IGNORE=(...)` and `ACCEPT=(...)` conditional filtering syntax.
- `PRED_IGNORE_DATA` for more complex exclusion logic.
- `NULL`, `MISDAT`, `BLANKOK`, `TRANSLATE`, and data-file path constraints.

Recommended new rules:

- `MT-NONMEM-003A`: `$INPUT` reserved labels and forbidden labels.
- `MT-NONMEM-003B`: DROP/SKIP allowed only for unused non-comment columns.
- `MT-NONMEM-003C`: DATE/TIME conversion and `DATE=DROP` convention.
- `MT-NONMEM-004B`: `IGNORE`/`ACCEPT` filtering logic and C-column convention.
- `MT-NONMEM-004C`: Advanced filtering with `PRED_IGNORE_DATA`.

### 2. Event Record Semantics Are Under-Specified

The current rules mention standard names but do not define how records drive model selection. NONMEM data documentation distinguishes:

- `DV` and `MDV`
- `ID`
- `EVID=0/1/2/3/4`
- `AMT`
- `RATE` including `RATE>0`, `RATE=0`, `RATE=-1`, `RATE=-2`
- `CMT` / `PCMT`
- `SS`, `II`, `ADDL`

These should become model-building rules. DuDu PMx should infer IV bolus, IV infusion, extravascular absorption, steady-state, repeated dosing, and reset-dose records from these fields before choosing an ADVAN template.

Recommended new rules:

- `MT-DATA-001`: Required observation/dose columns and semantics.
- `MT-DATA-002`: EVID/MDV consistency checks.
- `MT-DATA-003`: RATE/DUR/R1/D1 infusion handling.
- `MT-DATA-004`: ADDL/II/SS repeated-dose handling.
- `MT-DATA-005`: CMT/PCMT and depot/central/peripheral mapping.

### 3. BLQ/BQL Handling Is Too Thin

The dataset has `BQL`, but the rule library does not yet say how to model below-limit observations. This is important for monoclonal antibody PopPK, especially long terminal phases.

Missing:

- Clear definitions of BQL/BLQ, LLOQ, censoring vs missingness.
- Method selection: M1, M3, M4, M6/M7 variants.
- NONMEM implementation rules for likelihood-based M3/M4, including `F_FLAG=1` and Laplace/likelihood estimation implications.
- Diagnostic requirements: BQL proportion by time/dose, sensitivity analysis comparing M1 vs likelihood methods when BQL is material.

Recommended new rules:

- `MT-BLQ-001`: Do not treat BLQ as ordinary missingness without justification.
- `MT-BLQ-002`: Use M1 only when BLQ fraction is negligible or scientifically justified.
- `MT-BLQ-003`: M3/M4 likelihood templates for censored concentrations.
- `MT-BLQ-004`: BQL diagnostic plots and sensitivity analysis.

### 4. PREDPP / ADVAN / TRANS Decision Rules Need Expansion

The template library has a useful start, but the rule library should explicitly encode:

- ADVAN1/2/3/4 assumptions and compartment conventions.
- When to use ADVAN13/custom `$MODEL/$DES`.
- Absorption forms: first-order, zero-order, mixed absorption, lag time (`ALAG`), bioavailability (`F`), duration (`D1`) and rate (`R1`).
- Scaling parameters (`S1`, `S2`) and unit conventions.
- Central observation compartment by route.
- Two-compartment escalation criteria.
- TMDD / Michaelis-Menten escalation triggers.

Recommended new rules:

- `MT-PREDPP-001`: Route-to-template decision table.
- `MT-PREDPP-002`: Infusion coding with `D1`, `R1`, `RATE`, `DUR`.
- `MT-PREDPP-003`: Extravascular depot/central CMT conventions.
- `MT-PREDPP-004`: Scaling (`S1`, `S2`) and concentration units.
- `MT-PREDPP-005`: Criteria for moving to ADVAN13/custom ODEs.

### 5. `$OMEGA` / `$SIGMA` Matrix Rules Need Machine-Checkable Detail

Current rules say OMEGA is IIV variance and SIGMA is residual variance, but do not capture:

- Diagonal vs block OMEGA/SIGMA.
- `BLOCK(n)`, `BLOCK SAME`, `VALUES`, `VARIANCE`, `STANDARD`, `COVARIANCE`, `CORRELATION`, `CHOLESKY`.
- Positive definiteness and boundary checks.
- ETA count must match OMEGA dimensions.
- EPS count must match SIGMA dimensions.
- Fixed random effects and when `0 FIX` is allowed.
- Distinction between AutoPMX convention of estimating residual SD as THETA with `$SIGMA 1 FIX` vs traditional residual variance in `$SIGMA`.

Recommended new rules:

- `MT-RANDOM-001`: ETA/OMEGA dimension consistency.
- `MT-RANDOM-002`: EPS/SIGMA dimension consistency.
- `MT-RANDOM-003`: Boundary and positive-definite checks.
- `MT-RANDOM-004`: When to use correlated IIV blocks.
- `MT-RANDOM-005`: AutoPMX residual-error convention.

### 6. Estimation Method Selection Is Too Simplistic

Current AutoPMX defaults to `METHOD=1 INTER`. That is appropriate for many continuous PopPK models, but the rules should tell DuDu when not to use it.

Missing:

- FO/FOCE/FOCEI vs Laplace vs SAEM/IMP/BAYES decision rules.
- Laplace requirements for non-normal likelihoods/censored data.
- SAEM/IMP for complex nonlinear ODE/TMDD or difficult likelihoods.
- `MAXEVAL`, `SIGDIGITS`, `PRINT`, `NOABORT` conventions.
- Multi-step estimation and `MAXEVAL=0` evaluation runs.
- `SEED`/`CLOCKSEED` for stochastic methods and reproducibility.
- Boundary-test options and interpretation.

Recommended new rules:

- `MT-EST-001`: FOCEI default for continuous PopPK.
- `MT-EST-002`: Laplace for user-defined likelihood/censored or categorical data.
- `MT-EST-003`: SAEM/IMP for complex ODE/TMDD or difficult convergence.
- `MT-EST-004`: Stochastic method seed and reproducibility requirements.
- `MT-EST-005`: Retry strategy after failed minimization.

### 7. Run-Acceptance Logic Is Incomplete

Current model-evaluation rules cover GOF/VPC/bootstrap/shrinkage, but automated acceptance should include a fuller NONMEM output audit:

- Successful minimization.
- Covariance step successful.
- Parameter RSE thresholds by parameter type.
- Boundary estimates.
- Gradients and rounding errors.
- Condition number / correlation matrix red flags.
- OFV/AIC/BIC comparison.
- Eta and epsilon shrinkage.
- ETABAR / eta distribution centered near zero.
- Plausible parameter units and mAb half-life plausibility.
- No unmodeled trends in CWRES/time/IPRED/covariates.
- VPC stratified by dose/study/route when relevant.

Recommended new rules:

- `ME-NONMEM-001`: Minimization and covariance status.
- `ME-NONMEM-002`: Boundary/RSE/gradient checks.
- `ME-NONMEM-003`: Shrinkage and ETABAR interpretation.
- `ME-NONMEM-004`: Condition number/correlation matrix.
- `ME-NONMEM-005`: Model-comparison decision hierarchy.

### 8. Covariate Rules Need Safety Guardrails

Current covariate rules are good but high level. Missing:

- Missing covariate handling: imputation, indicator method, exclusion, or typical-value substitution.
- Time-varying covariates and when to carry forward/interpolate.
- Fixed allometry vs estimated exponents.
- Clinical relevance thresholds independent of statistical significance.
- Covariate plausibility hierarchy for mAbs: WT, albumin, sex, age, ADA, disease state, tumor burden/target burden, renal/hepatic only when biologically plausible.
- Avoid covariates when eta shrinkage is high.
- Avoid black-box SCM before stable structural/error/IIV model.

Recommended new rules:

- `CA-SAFETY-001`: Covariates only after stable base model.
- `CA-SAFETY-002`: Missing covariate handling must be explicit.
- `CA-MAB-001`: mAb covariate plausibility hierarchy.
- `CA-MAB-002`: Allometric scaling default and exceptions.
- `CA-SAFETY-003`: Shrinkage-aware covariate screening.

### 9. mAb-Specific Structural Rules Need More Operational Detail

The mAb biology rules are solid conceptually but not yet actionable for model generation.

Missing:

- Typical initial parameter ranges in consistent units.
- Linear vs nonlinear clearance criteria.
- TMDD escalation templates: Michaelis-Menten, QSS, quasi-equilibrium, full TMDD.
- ADA effect handling as time-varying covariate or clearance shift.
- Albumin/FcRn-related clearance effects.
- Body-weight allometry on CL and V.
- Dose-normalized exposure trends suggesting nonlinear clearance.

Recommended new rules:

- `MAB-STRUCT-001`: Initial parameter ranges by units.
- `MAB-STRUCT-002`: Linear clearance vs TMDD trigger.
- `MAB-STRUCT-003`: Michaelis-Menten/TMDD template decision.
- `MAB-COV-001`: ADA impact model forms.
- `MAB-COV-002`: Albumin and FcRn-related covariate checks.

### 10. PsN Automation Rules Are Too Minimal

AutoPMX uses PsN for execute, VPC, bootstrap, SCM. PsN itself is a broad toolset for model development, resampling, and diagnostics. Current config supports VPC samples, bootstrap samples, and stratification, but rules should add:

- Directory naming and no-overwrite behavior.
- Machine-readable outputs (`results.json`, `meta.yaml`) when available.
- VPC binning strategy: by count, custom endpoints, prediction-corrected VPC.
- VPC stratification decision: dose/study/route/ADA status.
- Bootstrap sample size and success-rate thresholds.
- SCM config provenance.
- Capture NONMEM/PsN/R versions.

Recommended new rules:

- `PSN-AUTO-001`: Always isolate outputs by run directory.
- `PSN-VPC-001`: VPC binning and stratification requirements.
- `PSN-VPC-002`: pcVPC trigger.
- `PSN-BOOT-001`: Bootstrap sample size and success criteria.
- `PSN-SCM-001`: SCM config and decision trace.
- `PSN-REPRO-001`: Version and seed capture.

### 11. Reporting Rules Need Reproducibility Artifacts

FDA and EMA both emphasize enough detail for review/secondary evaluation. AutoPMX reporting should require:

- Dataset path, dataset version/hash, number of subjects/records/observations/doses.
- Model lineage and exact run IDs.
- Control streams and outputs.
- NONMEM/PsN/R/package versions.
- Estimation method and settings.
- Parameter table with labels, estimates, SE/RSE, CI.
- GOF/VPC/bootstrap/SCM outputs.
- Known limitations and excluded records.
- Covariate rationale and clinical relevance.
- Final model simulation-readiness.

Recommended new rules:

- `REP-REPRO-001`: Dataset and code provenance.
- `REP-REPRO-002`: Software versions and run commands.
- `REP-REPRO-003`: Model lineage and decision log.
- `REP-REPRO-004`: Validation artifact checklist.

## Suggested Rule-File Restructure

The single `poppk_rules.json` is still manageable, but for automated model generation it would be cleaner to split or tag rules into layers:

1. `nonmem_syntax_rules.json`
   - `$INPUT`, `$DATA`, `$THETA`, `$OMEGA`, `$SIGMA`, `$EST`, `$TABLE`, reserved names, syntax constraints.
2. `poppk_modeling_strategy_rules.json`
   - Structural model, residual model, IIV, covariates, model comparison.
3. `diagnostic_acceptance_rules.json`
   - LST/EXT/COV audit, GOF, VPC, bootstrap, shrinkage, final model criteria.
4. `mab_domain_rules.json`
   - mAb-specific PK biology, TMDD, ADA, FcRn/albumin, expected parameter ranges.
5. `automation_guardrails.json`
   - Rules that the app can enforce before saving/running: C column, DATA path, table filenames, run IDs, no overwrite, output provenance.

## Immediate Implementation Recommendations

1. Add the high-priority NONMEM syntax rules to `poppk_rules.json`.
2. Add a Swift/Python model validator that checks every generated `.mod` before running:
   - `$INPUT` starts with `C`.
   - `$DATA` path exists and uses `IGNORE=C`.
   - Required variables for route are present.
   - `$TABLE` files have current run IDs.
   - ETA count matches OMEGA dimensions.
   - EPS count matches SIGMA dimensions.
   - `$ERROR` has guarded `W` and no divide-by-zero risk.
   - THETA/OMEGA/SIGMA labels exist for parameter extraction.
3. Expand `poppk_model_library.md` with:
   - ALAG/F/R/D templates.
   - SC/oral first-order absorption variants.
   - BQL M3/M4 templates.
   - TMDD/Michaelis-Menten templates.
   - IOV templates.
4. Make DuDu PMx prompt retrieval rule-aware:
   - syntax rules always included;
   - modeling strategy rules included during auto-build;
   - diagnostic rules included during evaluation;
   - reporting rules included when generating final reports.

## Bottom Line

The current knowledge base is enough for a prototype and guided manual modeling. For fully automated LLM-driven NONMEM model building, the most important missing layer is executable guardrails: detailed syntax rules, data/event semantics, estimation-method selection, BQL likelihood handling, and objective acceptance criteria. These should be added before trusting DuDu PMx to iterate models without human review.

