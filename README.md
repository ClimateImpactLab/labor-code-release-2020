# labor-code-release-2020

Plots needed


MAIN TEXT: DATA
Summary table (we already have this but will need to rearrange, update numbers. Ashwin will rearrange and coordinate with Kit and Rae to get the relevant numbers updated)

MAIN TEXT: THEORY
Ashwin and Ishan working on illustrated figures in this section

MAIN TEXT: RESPONSE FUNCTION ESTIMATES
NOTE: All FE regimes include the standard ADM3 FE and dow FE
Estimate common response (w/differentiated FE) for ADM0 week FE (Kit)
Tables of high- and low-risk responses, with different FEs (Kit)
Main model ("ADM0 x week" FE): Common, Low, High columns, with rows for 0,5,10,30,35,40
Low and High responses under following FE: "adm3_id dow_week adm0_id#month#year" "adm3_id dow_week adm0_id#year" "adm3_id dow_week adm0_id#week_fe adm0_id#year" "adm3_id dow_week adm3_id#month#year" . 3 low-risk columns, followed by 3 high-risk columns. Rows for temperature as above.

Place histograms under common-, high- and low-risk response plots (Kit)

MAIN TEXT: RISK SHARE ESTIMATES
Table of coefficient estimates, 2 columns- with and without continent FEs (might move to appendix)
level curves of income effect (at terciles of temperature)
level curves of temperature effect (at terciles of income)
WE ALREADY HAVE THE TWO LEVEL CURVE PLOTS FROM THE FED PRESENTATION

MAIN TEXT: POST-PROJECTION (examples of these are in Fed slides)
IMPACTS IN MINUTES
Impact map at 2099 for low- and high-risk workers
Share of high-risk workers map at 2020 and 2099
beta map for 37 C response (averaging across high- and low-risk responses by IR) at 2020 and 2099
overall impact map at 2099 (mins/person/day)
when we have uncertainty, we will add kernel density for selected IRs
time series of overall impacts (mins/person/day) under no adapt and full adapt
IMPACTS IN DOLLARS
Time series of monetized global disutility
Map of global monetized disutility at 2099 as percent of GDP
TBD some other spatial breakdown of monetized global disutility (e.g. countries)
DAMAGE FUNCTION
End-of-century damage function with GCM/RCP points
Extrapolated damage functions beyond 2100
PULSE FIGURE
Final damage panel to be updated
SCC table

APPENDICES

Functional form comparison (bins etc.)
Robustness projection using different high/low shares specification (without continent FEs)
Single projection with edge restrictions
Point estimate projection for different SSPs
Inclusion of China (response estimation and single projection)
Interacted model



projection (./generate.sh + yml) -> aggregation (./aggregate.sh + yml) -> extraction (single.py, quantiles.py)




