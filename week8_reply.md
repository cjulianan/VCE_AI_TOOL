# Week 8 Technical Reply and Implementation Guide

## Purpose

This document responds to the issues described in `Week 8 Issues.pdf` and provides a step-by-step implementation plan.

The reported failures come from several separate problems:

1. The Ragnar DuckDB store remains locked after it is built.
2. The application uses an incorrect retrieval argument (`limit` instead of `top_k`).
3. Retrieved Markdown chunks may contain multiple metadata paths, so one question can route to unrelated datasets.
4. Too many metadata schemas and data records are added to the LLM prompt.
5. The chatbot can query by locality FIPS, but it cannot query a hospital or other entity by name.
6. CCD Enrollment has no `GEOID` column, but the application falls back to `GEOID` when its metadata has no locality FIPS field.

These issues should be fixed separately and in the order below.

---

## Step 1: Separate the Store-Build Process from the Chatbot Process

### Problem

`build_registry_store.R` creates a writable Ragnar/DuckDB connection. When that script is sourced inside an RStudio session, the connection can remain open after the script finishes. The active process continues to own `registry_store.duckdb.wal`.

When the chatbot starts in another R process, DuckDB cannot open the store because the first process still holds the file lock.

The `.wal` file is not the root problem. The root problem is an active writer connection.

### Required change

Treat `build_registry_store.R` as a standalone build command. Do not source it and then launch the chatbot while the build connection is still alive.

Remove this line from the end of `build_registry_store.R`:

```r
ragnar_store_connect(location = db_path, read_only = TRUE)
```

The builder should only create, populate, and index the store. The chatbot should be responsible for opening the read-only connection.

### Recommended workflow

Run the builder from a terminal:

```bash
Rscript programs/chatbot/build_registry_store.R
```

Wait until that command exits completely. Then confirm that the main database exists:

```bash
ls -lh data/outcome/registry_store.duckdb
```

Only after the build process exits should the chatbot be started in a new process.

### Add an explicit startup check

Update the chatbot initialization:

```r
registry_store_path <- here("data", "outcome", "registry_store.duckdb")

if (!file.exists(registry_store_path)) {
  stop(
    "The registry store does not exist. Run: ",
    "Rscript programs/chatbot/build_registry_store.R"
  )
}

REGISTRY_STORE <- ragnar_store_connect(
  registry_store_path,
  read_only = TRUE
)
```

This produces a clear setup error instead of a confusing DuckDB failure.

### Important rule

Do not delete the `.wal` file while another R process is using the database. Stop the process that owns the connection first.

---

## Step 2: Use the Correct Ragnar Retrieval Arguments

### Problem

The current code contains two different retrieval calls:

```r
ragnar_retrieve(
  REGISTRY_STORE,
  text = user_prompt_clean,
  top_k = 10,
  deoverlap = FALSE
)
```

and:

```r
ragnar_retrieve(
  REGISTRY_STORE,
  text = input$user_prompt,
  limit = 3
)
```

`ragnar_retrieve()` uses `top_k`, not `limit`, to control retrieval size. Remove every `limit` argument passed to `ragnar_retrieve()`.

Official reference:

- <https://ragnar.tidyverse.org/reference/ragnar_retrieve.html>

### Required change

Use a small value while routing:

```r
semantic_results <- ragnar_retrieve(
  REGISTRY_STORE,
  text = user_prompt_clean,
  top_k = 2,
  deoverlap = TRUE
)
```

### Important limitation

`ragnar_retrieve()` combines vector similarity and BM25 results. `top_k` applies to the retrieval methods, and the combined result can contain more than one candidate. Reducing `top_k` is necessary, but it is not sufficient. The application must still select and validate the final dataset before querying data.

---

## Step 3: Stop Extracting Metadata Paths with a Regular Expression

### Problem

The current routing logic searches retrieved text with:

```r
gregexpr(
  "data/outcome/[A-Za-z0-9_./-]+\\.json",
  retrieved_text
)
```

Adding `/` fixed nested directory matching, but this approach remains fragile:

- It does not support `&`, spaces, parentheses, or other valid filename characters.
- One Markdown chunk may contain several registry entries.
- The regular expression extracts every path in every retrieved chunk.
- A disease question can therefore include the CCD Enrollment path even when CCD is not the best match.

The County Health path already demonstrates this problem because it contains `&`:

```text
data/outcome/County-Health-Rankings-&-Roadmaps/county_health_metadata.json
```

### Required change

Store `dataset_id` and `metadata_path` as structured columns in the Ragnar store. Do not recover them by parsing retrieved prose.

### Recommended version-1 registry store

The registry is small and each dataset should be one independent retrieval row. A version-1 Ragnar store is appropriate for this routing index.

```r
library(ragnar)
library(jsonlite)
library(purrr)
library(tibble)
library(here)
library(rlang)

db_path <- here("data", "outcome", "registry_store.duckdb")

registry <- jsonlite::fromJSON(
  here("data", "outcome", "master_registry.json"),
  simplifyVector = FALSE
)

registry_rows <- purrr::map_dfr(
  registry$routing_registry,
  function(entry) {
    keywords <- paste(unlist(entry$keywords), collapse = ", ")
    text <- paste0(
      "Dataset ID: ", entry$dataset_id, "\n",
      "Keywords: ", keywords, "\n",
      "Metadata path: ", entry$metadata_path
    )

    tibble::tibble(
      origin = paste0("registry://", entry$dataset_id),
      hash = rlang::hash(text),
      text = text,
      dataset_id = entry$dataset_id,
      metadata_path = entry$metadata_path
    )
  }
)

store <- ragnar_store_create(
  location = db_path,
  overwrite = TRUE,
  version = 1,
  embed = embed_ollama(model = "nomic-embed-text:latest"),
  extra_cols = data.frame(
    dataset_id = character(),
    metadata_path = character()
  )
)

ragnar_store_insert(store, registry_rows)
ragnar_store_build_index(store)

message("Registry store built successfully: ", db_path)
```

Each retrieval result will now contain its own `dataset_id` and `metadata_path` columns.

### Updated routing logic

```r
semantic_results <- ragnar_retrieve(
  REGISTRY_STORE,
  text = user_prompt_clean,
  top_k = 2,
  deoverlap = FALSE
)

candidates <- semantic_results |>
  dplyr::distinct(dataset_id, metadata_path, .keep_all = TRUE)

matched_metadata_paths <- candidates$metadata_path
```

The application should then select the best validated candidate for each user task. It should not execute every path returned by retrieval.

---

## Step 4: Add a Dataset-Selection Gate Before Query Execution

### Problem

The current code treats all retrieved metadata paths as query targets. This explains why a chickenpox question can eventually attempt a CCD Enrollment query.

### Required change

Separate retrieval from execution:

```text
User question
    -> retrieve candidate datasets
    -> rank and validate candidates
    -> select one dataset per sub-question
    -> execute the selected dataset query
```

For the current single-question prototype, begin with only the highest-ranked candidate. Log the other candidates for debugging, but do not execute them.

```r
if (nrow(candidates) == 0) {
  matched_metadata_paths <- character()
} else {
  matched_metadata_paths <- candidates$metadata_path[[1]]
}
```

Later, when multi-question support is added, each sub-question should independently select one or more datasets.

### Cache rule

Do not automatically reuse `last_metadata_path` for a clearly new question. Cache reuse should occur only when the prompt is a follow-up that lacks a new topic.

For example:

- “What about 2024?” can reuse the previous dataset.
- “Tell me about chickenpox in Accomack” should perform new routing.
- “Now show school enrollment” should not reuse the disease dataset.

---

## Step 5: Enforce a Context Budget

### Problem

The reported request contained approximately 228,639 input units, exceeding the model limit of 131,072.

This occurs because the application can include:

- multiple retrieved registry chunks;
- multiple metadata files;
- every column description from large metadata files;
- every selected data column;
- all matching rows serialized as JSON.

Reducing `top_k` alone will not solve this.

### Required safeguards

Apply all of the following limits:

1. Select one dataset per sub-question before loading its full metadata.
2. Select only columns relevant to the user question.
3. Add a SQL row limit.
4. Summarize metadata instead of sending thousands of column descriptions.
5. Check context size before calling the LLM.

### SQL row limit

```sql
SELECT selected_columns
FROM dataset
WHERE validated_conditions
LIMIT 50
```

### Metadata column limit

Do not send the entire AHRF schema. First rank metadata columns using the user question, then keep a small number such as 10-25 fields.

### Context-size check

Add a conservative application limit before the LLM request:

```r
max_context_characters <- 60000

if (nchar(data_context) > max_context_characters) {
  data_context <- substr(data_context, 1, max_context_characters)
  data_context <- paste0(
    data_context,
    "\n\n[Context truncated by the application.]"
  )
}
```

Character count is not the same as token count, but it provides a useful emergency guard. A tokenizer-based limit would be better if one is available for the selected model.

### Better long-term design

Retrieve metadata first, select relevant columns second, query data third, and send only the final compact result to the LLM.

---

## Step 6: Add Entity Lookup for the Bath Community Hospital Question

### Problem

The question:

> What is the city that Bath Community Hospital is in?

does not contain a county name. Therefore, `target_fips` is `NULL`.

The current code enters the metadata-only branch when a metadata path is found but no FIPS is found. It never searches the hospital CSV for `Bath Community Hospital`.

Adding `/` to the path regular expression only allows the program to find the metadata file. It does not implement entity lookup.

### Required change

Add an explicit entity-lookup operation for datasets with named entities.

For the hospital dataset:

```text
Entity column: LandmkName
Requested return column: City
```

Conceptual query:

```sql
SELECT LandmkName, City, FIPScode, FIPSname
FROM vgin_hospitals
WHERE lower(LandmkName) LIKE lower(?)
LIMIT 10
```

Use DBI parameters for the entity value. Dataset paths and column names must come from an application allowlist, not directly from model output.

### Expected behavior

```text
User question
    -> route to VGIN hospitals
    -> detect named-facility lookup
    -> search LandmkName
    -> return City and source dataset
```

---

## Step 7: Fix CCD Enrollment Locality Resolution

### Problem

CCD Enrollment contains:

```text
year, ncessch, enrollment, leaid, grade, race, sex
```

It does not contain `GEOID` or a county FIPS column.

When `locality_fips` is `null`, the current code falls back to:

```r
fips_col <- "GEOID"
```

The resulting query fails:

```sql
WHERE GEOID = '51001'
```

### Required change

Do not use a universal `GEOID` fallback. Metadata must declare a valid locality strategy.

For CCD Enrollment, use a bridge:

```text
County FIPS
    -> CCD Directory or institution-locality bridge
    -> one or more LEAIDs
    -> CCD Enrollment rows filtered by LEAID
```

### Important bridge correction

The bridge must contain all valid `leaid`-to-county relationships, not only school divisions that span multiple counties.

Recommended bridge columns:

```text
institution_id
institution_name
locality_fips
relationship_type
weight
```

### Query pattern

```sql
SELECT year, ncessch, enrollment, leaid, grade, race, sex
FROM ccd_enrollment
WHERE leaid IN (...validated LEAIDs...)
LIMIT 500
```

If a school division covers multiple localities, the response should explicitly state that the data belongs to a shared or regional division.

---

## Step 8: Handle Multiple Questions as Structured Tasks

This is not required to fix the immediate crashes, but it is the correct next architectural step.

Do not represent the prompt with only:

```text
one metadata path
one locality
```

Represent it as a list of tasks:

```json
[
  {
    "task_id": 1,
    "question": "What data do you have on crops?",
    "dataset_id": "nass_crops",
    "operation": "describe",
    "localities": []
  },
  {
    "task_id": 2,
    "question": "What city is Bath Community Hospital in?",
    "dataset_id": "vgin_hospitals",
    "operation": "entity_lookup",
    "entity": "Bath Community Hospital"
  }
]
```

Each task should be routed, validated, and executed independently. Results should retain their task ID and source before final answer synthesis.

---

## Step 9: Add Error Handling at Every Boundary

### Store connection

```r
REGISTRY_STORE <- tryCatch(
  ragnar_store_connect(registry_store_path, read_only = TRUE),
  error = function(e) {
    stop("Unable to open registry store: ", conditionMessage(e))
  }
)
```

### Retrieval

```r
semantic_results <- tryCatch(
  ragnar_retrieve(
    REGISTRY_STORE,
    text = user_prompt_clean,
    top_k = 2
  ),
  error = function(e) {
    warning("Semantic routing failed: ", conditionMessage(e))
    NULL
  }
)
```

### Metadata validation

Before querying:

- Confirm that the metadata file exists.
- Confirm that the data file exists.
- Confirm that every requested column exists in the data file.
- Confirm that the locality or entity strategy is supported.
- Reject queries that reference undeclared columns.

### Empty results

An empty query result should produce a controlled response:

```text
No matching records were found for the selected dataset, locality, and filters.
```

It should not silently fall back to an unrelated cached dataset.

---

## Step 10: Verify the Fixes with a Small Regression Test Set

Run these tests after every routing or metadata change.

### Test 1: Semantic synonym routing

Prompt:

```text
What data do you have on pathogens?
```

Expected:

- Routes to the reportable-disease dataset.
- Does not route to CCD Enrollment.
- Does not query data unless a locality or supported operation is supplied.

### Test 2: Entity lookup

Prompt:

```text
What is the city that Bath Community Hospital is in?
```

Expected:

- Routes to VGIN hospitals.
- Searches `LandmkName`.
- Returns the matching `City` value.
- Cites the hospital dataset.

### Test 3: Disease value lookup

Prompt:

```text
Tell me the incidence rate of chickenpox disease in Accomack County.
```

Expected:

- Routes only to the reportable-disease dataset.
- Resolves Accomack County to FIPS `51001`.
- Selects the appropriate disease, incidence-rate, and year fields.
- Does not execute a CCD query.
- Keeps the final prompt below the model context limit.

### Test 4: CCD Enrollment

Prompt:

```text
What enrollment data is available for Accomack County?
```

Expected:

- Routes to CCD Enrollment.
- Maps FIPS `51001` to valid LEAID values.
- Queries with `leaid`, not `GEOID`.
- Returns a controlled response even when no matching LEAID is available.

### Test 5: Store lifecycle

Procedure:

1. Run `Rscript programs/chatbot/build_registry_store.R`.
2. Confirm that the process exits.
3. Confirm that `registry_store.duckdb` exists.
4. Start the chatbot.

Expected:

- No `.wal` lock error.
- The chatbot connects read-only.
- Semantic retrieval succeeds.

### Test 6: Special-character path

Prompt:

```text
What county health ranking data is available?
```

Expected:

- Returns the structured County Health metadata path.
- Does not depend on regular-expression support for `&`.

### Test 7: Context budget

Prompt:

```text
What health-resource data is available for Accomack County?
```

Expected:

- Does not send the complete AHRF schema.
- Selects only relevant columns.
- Applies a row limit.
- Keeps the request below the configured context budget.

---

## Recommended Implementation Order

Complete the work in this order:

1. Remove the extra read-only connection from `build_registry_store.R`.
2. Run the builder only as a standalone `Rscript` process.
3. Add the chatbot startup file-existence check.
4. Replace `limit` with `top_k` in all Ragnar calls.
5. Rebuild the registry store with structured `dataset_id` and `metadata_path` columns.
6. Remove regular-expression path extraction.
7. Execute only the best validated dataset candidate per question.
8. Add context, column, and row limits.
9. Implement hospital/entity lookup.
10. Replace the CCD `GEOID` fallback with a FIPS-to-LEAID bridge.
11. Restrict cache reuse to genuine follow-up questions.
12. Run the complete regression test set.
13. After these fixes are stable, implement structured multi-question tasks.

---

## Definition of Done

The Week 8 issues should be considered resolved only when all of the following are true:

- The registry store can be rebuilt and reopened without a WAL lock.
- The chatbot starts with a clear message when the store is missing.
- Retrieval uses valid Ragnar arguments.
- Every retrieved result has one structured metadata path.
- A disease question cannot accidentally execute a CCD query.
- Bath Community Hospital can be queried by facility name.
- CCD Enrollment never queries a nonexistent `GEOID` column.
- Large metadata files do not exceed the model context limit.
- Every answer identifies its dataset and relevant locality or entity.
- The regression prompts produce repeatable results after a clean restart.

---

## Final Recommendation

Do not continue tuning `top_k` until the store lifecycle and routing representation are fixed. The most important design change is to make each registry entry an independent, structured retrieval record. Once routing returns one validated dataset path, context control, entity lookup, and dataset-specific query strategies become much easier to implement and test.

