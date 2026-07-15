# define where the registry store will be
db_path <- here("data/outcome/registry_store.duckdb")

# create registry store
REGISTRY_STORE <- ragnar_store_create(
  location = db_path,
  overwrite = TRUE,
  embed = embed_ollama(model = "nomic-embed-text:latest")
)

registry_doc <- read_as_markdown(here("data/outcome/master_registry.md"))
registry_chunks <- markdown_chunk(registry_doc)
ragnar_store_insert(REGISTRY_STORE, registry_chunks)
ragnar_store_build_index(REGISTRY_STORE)
ragnar_store_connect(location = db_path, read_only = TRUE)

message("Successfully built and indexed the new registry store!")
