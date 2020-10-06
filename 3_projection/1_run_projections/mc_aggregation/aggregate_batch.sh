n_threads=$1

conda activate risingverse
cd ~/repos/impact-calculations

./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_pop.yml $n_threads
./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_wage.yml $n_threads
./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_gdp.yml $n_threads
