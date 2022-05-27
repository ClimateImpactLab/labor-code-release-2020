source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr,
               glue,
               parallel,
               data.table)

DB <- ifelse(Sys.info()["nodename"]=="battuta", 
    "/mnt/sacagawea_shares/gcp/estimation/labor/code_release_int_data/projection_outputs/blob_plot", 
    "/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/blob_plot")

source("~/repos/labor-code-release-2020/4_post_projection/0_utils/covariate_coverage.R")

# Purpose: Generates Figure 3 in Rode et al. (2019), which compares
# in-sample vs. global loggdppc and climtas distributions in 2010 and 2100.

BLOB_OUTPUT= glue("{DIR_FIG}/main_model_single")
rcp='rcp85' 
iam='low'
ssp='SSP3'

#' Generates heat plot showing in-sample coverage of covariates in 2010 and 2100 
#' (Figure 3 in ------)). 
#' 
#' Inputs
#' ------
#' SSP, IAM, RCP scenario used to get the appropriate covariates. Note this
#' requires single projection output for those specifications.
#' 
#' Outputs
#' -------
#' Exports heat plots to `outputwd`.
#' 
#' Dependencies
#' -------------
#' impacts:::get_labor_covariates
#' 
#' Parameters/Return
#' -----------------
#' @param rcp RCP scenario (rcp45, rcp85)
#' @param iam Economic modelling scenario (low, high)
#' @param ssp SSP scenario (SSP2-4)
#' @param grayscale black and white alternative version for the print 
#' @param output_dir Output directory.
#' @return Exports plot, returns NULL.
blob_plot = function(
    rcp='rcp85',
    iam='high',
    ssp='SSP3',
    grayscale=FALSE,
    output_dir=BLOB_OUTPUT) {

    # Countries in sample.
    insample = c("ARG","AUT","BLR","BEN","BOL","BWA","BRA",
        "BFA","KHM","CMR","CAN","CHL","CHN","COL","CRI","DOM",
        "ECU","EGY","SLV","ETH","FJI","FRA","GHA","GRC","GTM",
        "GIN","HTI","HND","IND","IDN","IRQ","IRL","ISR","ITA",
        "JAM","JOR","LAO","LSO","LBR","MWI","MYS","MLI","MEX",
        "MNG","MAR","MOZ","NPL","NIC","NGA","PAK","PSE","PAN",
        "PRY","PER","PHL","POL","PRT","ROU","RWA","LCA","SEN",
        "SLE","SVN","ZAF","ESP","SDN","CHE","TZA","THA","TGO",
        "TTO","TUR","UGA","GBR","USA","URY","VEN","VNM","ZMB")

    # Load covariates.
    cov_path = '{DB}'
    # glue('{DB}/outputs/labor/impacts-woodwork/test_rcc_copy/',
    #     '/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
    #     '/{rcp}/CCSM4/{iam}/{ssp}/2_projection/3_impacts/')

    covars = get_labor_covariates(single_path=cov_path, year_list=c(2010, 2099)) %>%
        dplyr::mutate(
            year = ifelse(year==2099, 2100, year),
            iso = substr(region, 1, 3),
            grp = ifelse(iso %in% insample, 1, 0))

    # Divide up data.
    insample_2010 = dplyr::filter(covars, grp==1, year==2010)
    global_2010 = dplyr::filter(covars, year==2010)

    insample_2100 = dplyr::filter(covars, grp==1, year==2100)
    global_2100 = dplyr::filter(covars, year==2100)

    # Generate plots.

    if (grayscale){

        p = ggplot() +
            stat_bin_2d(data=global_2010, aes(x=climtas,y=loggdppc), colour="white", size=.2, geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="black", size=1, geom = "tile",na.rm=TRUE, fill=NA) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_2010_{rcp}-{iam}-{ssp}_grayscale.pdf')) 

        p = ggplot() +
            stat_bin_2d(data=global_2100, aes(x=climtas,y=loggdppc), colour="white", size=.2, geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="black", size=1, geom = "tile",na.rm=TRUE, fill=NA) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_2100_{rcp}-{iam}-{ssp}_grayscale.pdf')) 

    } else {

        p = ggplot() +
            stat_bin_2d(data=global_2010, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_world_2010_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("orange","red"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_sample_2010_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=global_2100, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_world_2100_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=insample_2100, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("orange","red"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_sample_2100_{rcp}-{iam}-{ssp}_new.pdf'))
    }
}   

blob_plot(rcp=rcp, iam=iam, ssp=ssp)
