# census_nass_fertilizers.csv

**Description:** United States Department of Agriculture (USDA) National Agricultural Statistics Service (NASS) data tracking fertilizer use from 2022 census.

- **Source Organization:** National Agricultural Statistics Service
- **Geographic Coverage:** county
- **Temporal Coverage:** 2022
- **URL Source:** [Link](https://quickstats.nass.usda.gov/api)
- **Spatial Alignment:** FIPS Column: `fips_code`, Locality Column: `county_name`

### Column Schema

* **`source_desc`** (*string*): Source of data (CENSUS or SURVEY). Census program includes the Census of Ag as well as follow up projects. Survey program includes national, state, and county surveys. *(Keywords: source desc, data source, census, survey)*
* **`sector_desc`** (*string*): Five high level, broad categories useful to narrow down choices (Crops, Animals & Products, Economics, Demographics, and Environmental). *(Keywords: sector desc, broad category)*
* **`group_desc`** (*string*): Subsets within sector (e.g., under sector = Crops, the groups are Field Crops, Fruit & Tree Nuts, Horticulture, and Vegetables). *(Keywords: group desc, group subset, field crops, vegetables)*
* **`commodity_desc`** (*string*): The primary subject of interest (e.g., CORN, CATTLE, LABOR, TRACTORS, OPERATORS) *(Keywords: commodity desc, crop name, product, item name)*
* **`class_desc`** (*string*): Generally a physical attribute (e.g., variety, size, color, gender) of the commodity. *(Keywords: class desc, variety, size)*
* **`prodn_practice_desc`** (*string*): A method of production or action taken on the commodity (e.g., IRRIGATED, ORGANIC, ON FEED). *(Keywords: prodn practice desc, production method, practice, organic, irrigated)*
* **`util_practice_desc`** (*string*): Utilizations (e.g., GRAIN, FROZEN, SLAUGHTER) or marketing channels (e.g., FRESH MARKET, PROCESSING, RETAIL). *(Keywords: util practice desc, utilization, marketing channel, grain, fresh market)*
* **`statisticcat_desc`** (*string*): The aspect of a commodity being measured (e.g., AREA HARVESTED, PRICE RECEIVED, INVENTORY, SALES). *(Keywords: statisticcat desc, metric, measurement aspect, area harvested, sales)*
* **`unit_desc`** (*string*): The unit associated with the statistic category (e.g., ACRES, $ / LB, HEAD, $, OPERATIONS). *(Keywords: unit desc, measurement unit, acres, dollars)*
* **`short_desc`** (*string*): A concatenation of six columns: commodity_desc, class_desc, prodn_practice_desc, util_practice_desc, statisticcat_desc, and unit_desc. *(Keywords: short desc, short description)*
* **`domain_desc`** (*string*): Generally another characteristic of operations that produce a particular commodity (e.g., ECONOMIC CLASS, AREA OPERATED, NAICS CLASSIFICATION, SALES). For chemical usage data, the domain describes the type of chemical applied to the commodity. The domain = TOTAL will have no further breakouts; i.e., the data value pertains completely to the short_desc. *(Keywords: domain desc, operation characteristic)*
* **`domaincat_desc`** (*string*): Categories or partitions within a domain (e.g., under domain = Sales, domain categories include $1,000 TO $9,999, $10,000 TO $19,999, etc). *(Keywords: domaincat desc, domain category)*
* **`agg_level_desc`** (*string*): Aggregation level or geographic granularity of the data (e.g., State, Ag District, County, Region, Zip Code). *(Keywords: ag level desc, geographic granularity, aggregation level, scale)*
* **`state_ansi`** (*int*): American National Standards Institute (ANSI) standard 2-digit state codes. *(Keywords: state ansi, state code)*
* **`state_fips_code`** (*string*): NASS 2-digit state codes; include 99 and 98 for US TOTAL and OTHER STATES, respectively; otherwise match ANSI codes. *(Keywords: state fips code)*
* **`state_alpha`** (*string*): State abbreviation, 2-character alpha code. *(Keywords: state alpha, state abbreviation)*
* **`state_name`** (*string*): State full name. *(Keywords: state name, state text)*
* **`asd_code`** (*int*): NASS defined county groups, unique within a state, 2-digit ag statistics district code. *(Keywords: asd code, ag district code)*
* **`asd_desc`** (*string*): Ag statistics district name. *(Keywords: asd desc, agricultural district)*
* **`county_ansi`** (*int*): ANSI standard 3-digit county codes. *(Keywords: county ansi, ansi county code)*
* **`county_code`** (*int*): NASS 3-digit county codes; includes 998 for OTHER (COMBINED) COUNTIES and Alaska county codes; otherwise match ANSI codes. *(Keywords: county code, nass county code)*
* **`county_name`** (*string*): County name. *(Keywords: county name, locality text)*
* **`location_desc`** (*string*): Full description for the location dimension. *(Keywords: location desc, geographic boundary)*
* **`year`** (*int*): The numeric year of the data. *(Keywords: year, calendar year, time period)*
* **`freq_desc`** (*string*): Length of time covered (Annual, Season, Monthly, Weekly, Point in Time). Monthly often covers more than one month. Point in Time is as of a particular day. *(Keywords: freq_desc, time frequency, update)*
* **`Value`** (*int*): Published data value or suppression reason code. *(Keywords: Value, metric value, amount count)*
* **`CV (%)`** (*float*): Coefficient of variation. Available for the 2012 Census of Agriculture only (county-level CVs are generalized). Suppressed data is marked as '(D)' for privacy disclosure, '(H)' for high statistical error/unreliability, or '(L)' for values too low to round. *(Keywords: CV (%), coefficient of variation, error percentage)*
* **`fips_code`** (*string*): The 5-digit Federal Information Processing Standard (FIPS) code uniquely identifying the county. Combines the 2-digit state FIPS code and the 3-digit county code. Maintained as a string to preserve leading zeros. *(Keywords: fips, county)*

