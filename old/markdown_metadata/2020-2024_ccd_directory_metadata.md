# 2020-2024_ccd_directory.csv

**Description:** Public school directory tracking geographic locations and administrative IDs.

- **Source Organization:** Common Core of Data (CCD)
- **Geographic Coverage:** county
- **Temporal Coverage:** 2020-2024
- **URL Source:** [Link](https://educationdata.urban.org/documentation/index.html)
- **Spatial Alignment:** FIPS Column: `county_code`, Locality Column: ``

### Column Schema

* **`year`** (*int*): The specific school year the directory information represents. *(Keywords: year, school year, academic year, time period)*
* **`school_name`** (*string*): The official text name of the public school. *(Keywords: school name, institution name)*
* **`ncessch`** (*int*): The 12-digit unique national public school ID used to cross-reference school directory details. *(Keywords: ncessch, school id)*
* **`leaid`** (*int*): The 7-digit unique Local Education Agency ID mapping the school directly to its school district. *(Keywords: leaid, district, school district)*
* **`lea_name`** (*string*): The official text name of the Local Education Agency (the school district). *(Keywords: district name, school district name)*
* **`county_code`** (*int*): The unique Federal Information Processing Series (FIPS) county code where the school is located. *(Keywords: county code, fips)*
* **`city_location`** (*string*): The city or municipality name where the school is physically located. *(Keywords: city location, town, municipality)*
* **`urban_centric_locale`** (*string*): Classifier for the school's location environment (e.g., City, Suburb, Town, Rural). *(Keywords: location, setting, environment)*
* **`longitude`** (*float*): The precise geographic longitude coordinate of the school for mapping and distance math. *(Keywords: longitude, coordinates, coords, location)*
* **`latitude`** (*float*): The precise geographic latitude coordinate of the school for mapping and distance math. *(Keywords: latitude, coordinates, coords, location)*
* **`school_level`** (*string*): The operational level of the school (e.g., Primary, Middle, High, Other). *(Keywords: school level, instructional level)*
* **`school_type`** (*string*): The classification type of the school (e.g., Regular school, Special education). *(Keywords: school type, school classification)*
* **`charter`** (*string*): An indicator flag indicating whether the institution is a public charter school. *(Keywords: charter, charter school)*
* **`magnet`** (*string*): An indicator flag indicating whether the institution offers a magnet program or is a magnet school. *(Keywords: magnet, magnet school)*
* **`virtual`** (*string*): An indicator classifying the school's level of virtual/remote instruction. *(Keywords: virtual, virtual school, remote instruction, online school)*
* **`enrollment`** (*int*): The total student enrollment count reported for the school during this directory year. *(Keywords: enrollment, student count, enrollment size, total students)*
* **`teachers_fte`** (*int*): The total Full-Time Equivalent (FTE) classroom teacher count employed at the school. *(Keywords: teachers, faculty, instructors, full time)*
* **`free_or_reduced_price_lunch`** (*int*): The total number of students eligible to receive free or reduced-price lunch. *(Keywords: free or reduced lunch, free lunch, reduced lunch)*
* **`direct_certification`** (*int*): The count of students directly certified for free meals through assistance programs like SNAP. *(Keywords: direct_certification, snap benefits, certified meals)*

