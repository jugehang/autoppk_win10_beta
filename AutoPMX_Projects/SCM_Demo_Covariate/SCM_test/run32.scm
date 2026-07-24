model = run32.mod
threads =4
search_direction=both
p_forward=0.05
p_backward=0.01
abort_on_fail=0

continuous_covariates=AGE,WT
categorical_covariates=SEX

[test_relations]
CL=AGE,WT,SEX
CLM=AGE,WT,SEX

[valid_states]
continuous = 1,5
categorical = 1,2
