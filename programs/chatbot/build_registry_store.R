# Purpose of this script is to seperate the registry store build logic from main chatbot script so it's easier to debug

# define where the registry store will be
db_path <- here("data/outcome/registry_store.duckdb")

# check for any leftover connections for object in memory and disconnect if so
if (exists("REGISTRY_STORE") && inherits(REGISTRY_STORE, "DuckDBRagnarStore")) {
  try(dbDisconnect(REGISTRY_STORE@con, shutdown = TRUE), silent = TRUE)
}

if (file.exists(db_path)) {
  # if the file already exists connect to it
  message("Registry store already exists. Connecting to it...")
  
  REGISTRY_STORE <- ragnar_store_connect(location = db_path, read_only = TRUE)
} else {
  # else build the registry store
  message("Registry store not found. Creating and building a new store...")
  
  REGISTRY_STORE <- ragnar_store_create(
    location = db_path,
    overwrite = TRUE,
    embed = embed_ollama(model = "nomic-embed-text:latest")
  )
  
  registry_doc <- read_as_markdown(here("data/outcome/master_registry.md"))
  registry_chunks <- markdown_chunk(registry_doc)
  ragnar_store_insert(REGISTRY_STORE, registry_chunks)
  ragnar_store_build_index(REGISTRY_STORE)
  
  # disconnect from write mode and open back in read only mode so chatbot can look through the register store
  dbDisconnect(REGISTRY_STORE@con, shutdown = TRUE)
  REGISTRY_STORE <- ragnar_store_connect(location = db_path, read_only = TRUE)
  
  message("Successfully built and indexed the new registry store!")
}