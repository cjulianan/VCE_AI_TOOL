# 🤖 VCE AI Tool


VCE AI Tool is a Retrieval-Augmented Generation (RAG) chatbot designed to help Virginia Cooperative Extension (VCE) agents quickly access insights and data about communities across the Commonwealth.

---

### 📝 Description

Standard LLMs frequenty hallucinate and give false answers to the user. VCE AI Tool mitigates these hallucinations by using RAG, which limits the chatbot to only answer based on the datasets it is provided ([Cheng et al., 2025](https://arxiv.org/abs/2503.10677)). The goal of this chatbot is to enable VCE agents to efficiently access complex data and turn that information to respond to emerging local needs.

---

### 📂 Repository Structure

The current repository is structured as follows:

```text
├── _old/                           # Archived files/scripts
├── data/                           # Data storage directory for chatbot to reference
│   ├── outcome/                    # Cleaned/processed datasets sorted by organization (American Community Survey, Virginia Department of Health, etc.)
│   └── sources/                    # Raw source datasets sorted by organization (American Community Survey, Virginia Department of Health, etc.)
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

* Cheng, M., Luo, Y., Ouyang, J., Liu, Q., Liu, H., Li, L., ... & Chen, E. (2025). A survey on knowledge-oriented retrieval-augmented generation. arXiv preprint arXiv:2503.10677. 
