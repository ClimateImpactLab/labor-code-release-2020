
uname="$USER"
cd "/home/${uname}/repos/impact-calculations"
for i in {1..20}
do 
	echo "Process ${i}"
	./generate.sh ../labor-code-release-2020/3_projection/1_run_projections/mc/uninteracted_main_model_sac_mc_config.yml 1
	sleep 15m
done

for i in {3..14}
do 
	rm -r batch${i}/rcp85/bcc-csm1-1/	
done

