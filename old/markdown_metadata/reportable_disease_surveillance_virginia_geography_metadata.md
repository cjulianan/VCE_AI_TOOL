# reportable_disease_surveillance_virginia_geography

**Description:** Virginia Department of Health public use dataset containing annual case counts and incidence rates for reportable diseases.

- **Source Organization:** Virginia Department of Health
- **Geographic Coverage:** county
- **Temporal Coverage:** 2024
- **URL Source:** [Link](https://data.virginia.gov/dataset/vdh_pud_reportable-disease-surveillance-virginia_geography)
- **Spatial Alignment:** FIPS Column: `FIPS`, Locality Column: `Geography Value`

### Column Schema

* **`Year`** (*int*): The specific year the disease surveillance data was recorded. *(Keywords: Year, calendar year, time period)*
* **`Condition`** (*string*): The name of the reportable disease. *(Keywords: Condition, disease, illness, sickness, infection)*
* **`Geography Level`** (*string*): The scale of the geographic boundary used for reporting, typically classified as State, Health Planning Region, or Locality. *(Keywords: Geography Level, geographic scale, region type)*
* **`Geography Value`** (*string*): The specific text name of the reporting area corresponding to the geography level (e.g., Virginia, Eastern Region, Fairfax County). *(Keywords: Geography Value, location name, region name, county name, locality)*
* **`FIPS`** (*int*): The standard Federal Information Processing Series numeric code uniquely identifying the specific Virginia county, independent city, or state boundary. *(Keywords: FIPS, location id)*
* **`Annual Case Count`** (*int*): The total integer count of confirmed or probable cases of the condition reported within that geography during the calendar year. *(Keywords: Annual Case Count, total cases, number of cases)*
* **`Incidence Rate`** (*float*): The calculated rate of disease occurrence expressed as the number of reported cases per 100,000 population within the specified geography. *(Keywords: Incidence Rate, frequency rate, cases per 100k)*

