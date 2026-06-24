# VCE AI Tool


VCE AI Tool is a Retrieval-Augmented Generation (RAG) chatbot designed to help Virginia Cooperative Extension (VCE) agents quickly access insights and data about communities across the Commonwealth. The motivation of this chatbot is to enable VCE agents to efficiently access complex data and use that information to respond to emerging local needs.

---

### 📝 Description

Standard LLMs frequenty hallucinate and give false answers to the user. VCE AI Tool mitigates these hallucinations by using RAG, which limits the chatbot to only answer based on the datasets it is provided ([Cheng et al., 2025](https://arxiv.org/abs/2503.10677)). In addition, we aim to apply prompt scaffolding frameworks, guardrails to user prompts, to filter out potential noise and improve the accuracy of retrieval ([Quintero, 2025](https://dspace.mit.edu/entities/publication/f748ebfd-082b-48af-8edb-c3959ff1ca85)). In previous literature reviewed, chatbots employing RAG were used to analyze country level data and soley focused on tabular data ([Ali et al. 2025](https://link.springer.com/chapter/10.1007/978-3-032-18487-0_2)). Our chatbot's contribution will be to focusing on the county level of the state of Virginia and also the incorporation of spatial data. 

---
### 📂 Repository Structure

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

### 📚 References
* Ali, M., Maratsi, M. I., Lachana, Z., Charalabidis, Y., Alexopoulos, C., & Loukis, E. (2025, September). Talk to Open Data: Enabling User Interaction with Open Government Data Using LLMs, RAG and Smart Agent Technologies. In European, Mediterranean, and Middle Eastern Conference on Information Systems (pp. 15-31). Cham: Springer Nature Switzerland. 
* Cheng, M., Luo, Y., Ouyang, J., Liu, Q., Liu, H., Li, L., ... & Chen, E. (2025). A survey on knowledge-oriented retrieval-augmented generation. arXiv preprint arXiv:2503.10677.
* Quintero, S. (2025). Retrieval-Augmented Generation for Large Language Models: Enhancing Applied Economic Reasoning and Forecasting (Doctoral dissertation, Massachusetts Institute of Technology). 
