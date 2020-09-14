
uname="$USER"
cd "/home/${uname}/repos/impact-calculations"
for i in {1..10}
do 
	echo "Process ${i}"
	./generate.sh ../labor-code-release-2020/3_projection/1_run_projections/mc/uninteracted_main_model_sac_mc_config.yml 1
	sleep 1h
done

