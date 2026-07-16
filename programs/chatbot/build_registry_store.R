# define where the registry store will be
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
    ) # makes master registry JSON into a Data Frame object
    
    tibble::tibble(
      origin = paste0("registry://", entry$dataset_id),
      hash = rlang::hash(text),
      text = text,
      dataset_id = entry$dataset_id,
      metadata_path = entry$metadata_path
    )
  }
)

# create registry store
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
