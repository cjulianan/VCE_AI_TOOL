# VCE AI Tool


VCE AI Tool is a Retrieval-Augmented Generation (RAG) chatbot designed to help Virginia Cooperative Extension (VCE) agents quickly access insights and data about communities across the Commonwealth. The motivation of this chatbot is to enable VCE agents to efficiently access complex data and use that information to respond to emerging local needs.

---

## 📝 Description

Standard LLMs frequenty hallucinate and give false answers to the user. VCE AI Tool mitigates these hallucinations by using RAG, which limits the chatbot to only answer based on the datasets it is provided ([Cheng et al., 2025](https://arxiv.org/abs/2503.10677)). In addition, we aim to apply prompt scaffolding frameworks, guardrails to user prompts, to filter out potential noise and improve the accuracy of retrieval ([Quintero, 2025](https://dspace.mit.edu/entities/publication/f748ebfd-082b-48af-8edb-c3959ff1ca85)). In previous literature reviewed, chatbots employing RAG were used to analyze country level data and soley focused on tabular data ([Ali et al., 2025](https://link.springer.com/chapter/10.1007/978-3-032-18487-0_2)). Our chatbot's contribution will be to focusing on the county level of the state of Virginia and also the incorporation of spatial data. 

---

## 📊 Data Pipeline

**Data Collection:**

Currently, the chatbot contains tabular datasets spanning across the topics of health, education, and agriculture that cover the county level of Virginia. These datasets were either downloaded from online websites or from public APIs. Datasets were also cleaned using R, to ensure consistency (e.g. filtering out unused variables, adding FIPS code variables, and keeping only relevant years).  

**Metadata:**

Each dataset has a corresponding metadata file to provide detailed descriptions of that dataset. The only difference in metadata column format is for American Community Survey (columns has variable codes and human label) and Area Health Resources files (columns has only name and description). 

* **File Paths:** `File Name` • `File Path` • `Raw File Path` • `URL Source`
* **Context:** `Description` • `Organization` • `Geographic Level` • `Time Coverage`
* **Structure:** `Unit of Analysis` • `Primary Keys` • `Join Keys`
* **Processing:** `Cleaning Scripts` • `Spatial Alignments`
* **Columns Schema:** `Variable Name`, `Data Type`, `Keywords`, `Description`, `Missing Values`

In addition to a metadata file for each dataset, a master registry metadata file is used as a comprehensive metadata file for every dataset.

* **Registry Fields:** `Dataset ID` • `Metadata Path` • `Keywords`

**Chatbot Data Retrieval Process:**

All metadata files are embedded through the R package Ragnar, to provide semantic meaning through numerical representation to those files. These embedded metadata are all stored inside a DuckDB registry store file.

When the user asks a prompt, Ragnar ranks the top k relevant metadata and picks the top candidate to use to generate the answer. The metadata contains the path to the dataset, which DuckDB uses to query and retrieve the specific answer.

**Data and Metadata Repository Locations:**

| Location | Content | Notes |
| :--- | :--- | :--- |
| `programs/cleaning/` | Cleaning scripts | |
| `references/codebook/` | Codebooks | Sorted by organization |
| `data/sources/` | Uncleaned datasets | Sorted by organization |
| `data/outcome/` | Cleaned datasets | Sorted by organization |
| `data/outcome/_All_Metadata/` | All metadata files | Also saved alongside datasets |
| `data/outcome/` | Master registry & Registry store | Standalone files |

**List of Datasets by Topic**
<details>
<summary><b>🏥 Health Datasets</b></summary>

* **Area Health Resources Files**
  * **Organization:** Health Resources and Services Administration
  * **Datasets:** Area Health Resources Files (includes health facilities, professions, training programs etc.)
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 01/29/2026
  * **URL:** https://data.hrsa.gov/data/download
  * **API Dependencies:** None
  * **Known Limitations:** Metadata file too large. Exceeds model’s maximum context length so will need to add context size check into chatbot code to fix.

* **Virginia Hospitals**
  * **Organization:** Virginia Geographic Information Network
  * **Datasets:** Virginia Hospitals (includes locations of hospitals)
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 11/13/2025
  * **URL:** https://vgin.vdem.virginia.gov/datasets/cc17f1dd831d48e98ac6d5a3593a67d4_1/explore?location=37.933550%2C-79.504900%2C6
  * **API Dependencies:** None
  * **Known Limitations:** None

* **Depression Risk**
  * **Organization:** Mental Health America
  * **Datasets:** Number of People at Risk of Depression Per 100K of County Population (includes PTSD and trauma)
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 11/13/2025
  * **URL:** https://mhanational.org/data-in-your-community/mha-state-county-data/
  * **API Dependencies:** None
  * **Known Limitations:** None

* **Reportable Disease Surveillance**
  * **Organization:** Virginia Department of Health
  * **Datasets:** Reportable Disease Surveillance Virginia Geography
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 2025
  * **URL:** https://data.virginia.gov/dataset/vdh_pud_reportable-disease-surveillance-virginia_geography
  * **API Dependencies:** None
  * **Known Limitations:** None

* **County Health Rankings**
  * **Organization:** County Health Rankings & Roadmaps
  * **Datasets:** 2025 County Health Rankings Virginia Data (including mental health providers, food environment index, air quality etc.)
  * **Update Frequency:** Annual
  * **Last Time Updated as of 6/3/2026:** 2025
  * **URL:** https://www.countyhealthrankings.org/health-data/virginia/data-and-resources
  * **API Dependencies:** None
  * **Known Limitations:** None

</details>

<details>
<summary><b>🎓 Education Datasets</b></summary>

* **CCD Directory**
  * **Organization:** Common Core Dataset (Sourced by Urban Institute)
  * **Datasets:** 2020-2024 CCD Directory (including school levels, type, enrollment etc.)
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 2024
  * **URL:** https://github.com/UrbanInstitute/education-data-package-r
  * **API Dependencies:** Education Data Portal from Urban Institute
  * **Known Limitations:** None

* **SOL Test Results**
  * **Organization:** Virginia Department of Education
  * **Datasets:** Standards of Learning Test Results (including state testing pass rates)
  * **Update Frequency:** Annually
  * **Last Time Updated as of 6/3/2026:** 2025
  * **URL:** https://www.doe.virginia.gov/data-policy-funding/data-reports/statistics-reports/sol-test-pass-rates-other-results
  * **API Dependencies:** None
  * **Known Limitations:** None

* **Special Education Child Count**
  * **Organization:** Virginia Department of Education
  * **Datasets:** Special Education Child Count (including total count of students with special education needs)
  * **Update Frequency:** See known limitation
  * **Last Time Updated as of 6/3/2026:** 2023
  * **URL:** https://data.virginia.gov/dataset/special-education-child-count-2022-2023
  * **API Dependencies:** None
  * **Known Limitations:** Inconsistent updates (updated annually since 2019 but nothing since 2023)

</details>

<details>
<summary><b>🌾 Agriculture Datasets</b></summary>

* **Quick Stats Database**
  * **Organization:** National Agricultural Statistics Service
  * **Datasets:** Quick Stats Database (including crops, fertilizers, irrigation etc.)
  * **Update Frequency:** Each Weekday
  * **Last Time Updated as of 6/3/2026:** 6/3/2026
  * **URL:** https://quickstats.nass.usda.gov/api
  * **API Dependencies:** rnassqs package from R
  * **Known Limitations:** None

</details>

<details>
<summary><b>🌐 General Datasets (Education & Health)</b></summary>

* **American Community Survey**
  * **Organization:** American Community Survey (Census Bureau)
  * **Datasets:** ACS 5-year (including health insurance, disabilities, educational attainment, etc.)
  * **Update Frequency:** Annual
  * **Last Time Updated as of 6/3/2026:** 2025
  * **URL:** https://www.census.gov/data/developers/data-sets.html
  * **API Dependencies:** Tidycensus R package
  * **Known Limitations:** None

</details>

---

## 📂 Repository Structure

The current repository is structured as follows:

```text
├── data/                           # Data storage directory for chatbot to reference
│   ├── outcome/                    # Cleaned/processed datasets sorted by organization (American Community Survey, Virginia Department of Health, etc.)
│   └── sources/                    # Raw source datasets sorted by organization (American Community Survey, Virginia Department of Health, etc.)
├── old/                           # Archived files/scripts
├── programs/                       # Active code and processing logic
│   ├── chatbot/                    # Scripts to run chatbot
│   ├── cleaning/                   # Data cleaning scripts
│   ├── data_availability_dashboard/ # Scripts for visualizing available data metrics
│   └── _master.qmd                 # Master Quarto document to fully setup RStudio before running R scripts
├── references/                     # Supporting literature and domain resources
│   ├── codebook/                   # Sorted by organizations with existing codebooks for data used
│   └── literature-review/          # Background research and literature review files for project
├── .gitignore                      # Configured to secure credential files
└── VCE_AI_TOOL.Rproj               # RStudio Project configuration file
```

---

## 📚 References
* Ali, M., Maratsi, M. I., Lachana, Z., Charalabidis, Y., Alexopoulos, C., & Loukis, E. (2025, September). Talk to Open Data: Enabling User Interaction with Open Government Data Using LLMs, RAG and Smart Agent Technologies. In European, Mediterranean, and Middle Eastern Conference on Information Systems (pp. 15-31). Cham: Springer Nature Switzerland. 
* Cheng, M., Luo, Y., Ouyang, J., Liu, Q., Liu, H., Li, L., ... & Chen, E. (2025). A survey on knowledge-oriented retrieval-augmented generation. arXiv preprint arXiv:2503.10677.
* Quintero, S. (2025). Retrieval-Augmented Generation for Large Language Models: Enhancing Applied Economic Reasoning and Forecasting (Doctoral dissertation, Massachusetts Institute of Technology). 
