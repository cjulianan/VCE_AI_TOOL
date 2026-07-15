# vgin_hospitals.csv

**Description:** Geospatial information on inpatient, outpatient, and mental health hospital facilities across Virginia counties, maintained by the Virginia Geographic Information Network (VGIN).

- **Source Organization:** Virginia Geographic Information Network
- **Geographic Coverage:** county
- **Temporal Coverage:** 2024
- **URL Source:** [Link](https://vgin.vdem.virginia.gov/datasets/VGIN::virginia-hospitals/about)
- **Spatial Alignment:** FIPS Column: `FIPScode`, Locality Column: `FIPSname`

### Column Schema

* **`LandmkName`** (*String*): The official name of the healthcare facility or landmark. *(Keywords: hospital name, facility name, clinic name, medical center)*
* **`Address`** (*String*): The physical street address of the hospital facility. *(Keywords: street address, location, where is)*
* **`City`** (*String*): The city or town where the facility is located. *(Keywords: city, town, municipality)*
* **`Zip`** (*String*): The 5-digit postal ZIP code for the facility. *(Keywords: zip code, postal code)*
* **`X`** (*Double*): The geographic longitude coordinate in decimal degrees for spatial mapping. *(Keywords: longitude, x coordinate)*
* **`Y`** (*Double*): The geographic latitude coordinate in decimal degrees for spatial mapping. *(Keywords: latitude, y coordinate)*
* **`LastCheck`** (*String*): The timestamp indicating when the facility records were last verified or updated by the source agency. *(Keywords: date updated, last checked, data currency)*
* **`SrcTyp`** (*String*): The specific operating classification of the hospital (e.g., Inpatient Hospital, Outpatient Surgical Hospital). *(Keywords: facility type, hospital classification, inpatient, outpatient)*
* **`Src`** (*String*): The state agency providing the registry data (e.g., Virginia Department of Health [VDH], Department of General Services [DGS]). *(Keywords: data source, agency provider, vdh)*
* **`FIPScode`** (*Integer*): The 5-digit Federal Information Processing Standard (FIPS) code uniquely identifying the Virginia county or independent city. *(Keywords: fips, county code, geographic id)*
* **`FIPSname`** (*String*): The name of the Virginia county or independent city hosting the facility. This matches the output of the string extractor. *(Keywords: county name, city name, locality, jurisdiction)*

