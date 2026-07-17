# Week 8 Technical Reply — July 16 Update

## Executive Summary

The proposed stateful-chat direction is reasonable for conversational continuity, but conversation history should not replace deterministic application state. The safest design is a hybrid architecture:

- Use stateful LLM history to preserve natural dialogue and interpret short follow-up questions.
- Keep a small structured state object in R for facts that must remain exact, including the active dataset, location, filters, year range, and pending clarification.
- Re-query DuckDB whenever the requested information is not already present in the validated context.
- Add an explicit relevance decision before treating semantic-search results as a new topic.

The current assumption that a follow-up question will naturally produce zero semantic matches is unsafe. A top-k vector search normally returns the nearest candidates even when none is sufficiently relevant. Without a score threshold or a follow-up classifier, a question such as “What about in 2024?” may incorrectly select a new dataset instead of using the active conversation state.

## Response to the July 16 Proposal

### 1. Should the chatbot become stateful?

Yes, the chatbot can remain stateful so that the LLM can understand conversational references such as:

- “What about in 2024?”
- “How does that compare with the previous year?”
- “Can you show the same result as a percentage?”

However, LLM history should be treated as conversational evidence, not as the authoritative data store. An LLM may misunderstand an older turn, reuse an outdated filter, or combine information from unrelated topics. Important state should therefore remain machine-readable and independently verifiable.

Recommended minimal state:

```r
active_state <- reactiveValues(
  dataset_id = NULL,
  metadata_path = NULL,
  user_intent = NULL,
  geography_type = NULL,
  geography_name = NULL,
  geography_id = NULL,
  filters = list(),
  requested_years = NULL,
  loaded_years = NULL,
  selected_columns = NULL,
  pending_clarification = NULL,
  original_query = NULL
)
```

This is smaller and safer than using a large custom response cache. It records only the information needed to interpret and validate the next turn.

### 2. Should the current R cache be removed?

The response cache can be removed if it is being used to store complete prompts, large query results, or generated answers. However, structured state should not be removed completely.

At minimum, the application still needs state for:

1. Ambiguous location clarification, such as choosing between Richmond city and Richmond County.
2. The currently active dataset and query parameters.
3. The original question while a clarification is pending.
4. Session export and restoration.
5. Determining whether a follow-up requires another database query.

For example:

```text
User: What was the population of Richmond in 2023?
Assistant: Do you mean Richmond city or Richmond County?
User: City.
```

The final message, “City,” is not meaningful without the original query and the list of pending candidates. This information should be stored explicitly rather than inferred only from model history.

### 3. Can an empty semantic-search result identify a follow-up question?

Not reliably.

The current routing code requests the top three nearest results. Nearest-neighbor search may return candidates for every query, including vague follow-ups. Therefore, the following rule is unsafe:

```text
No semantic matches -> follow-up
Any semantic match  -> new topic
```

The router should instead produce one of three decisions:

```text
FOLLOW_UP
NEW_TOPIC
NEEDS_CLARIFICATION
```

A recommended decision process is:

1. Check whether the message contains a reference to the active task, such as “that,” “same,” “also,” “previous year,” or a short change in year/location.
2. Run semantic retrieval.
3. Accept a new dataset only when the best result passes a tested relevance threshold.
4. Compare the best and second-best results. A small score margin may indicate ambiguity.
5. If the message is a likely follow-up and no strongly relevant new dataset exists, retain the active dataset.
6. Ask a clarification question when neither interpretation is sufficiently reliable.

The threshold must be calibrated using representative user queries. It should not be selected from one or two examples.

## Required Query Behavior

Stateful conversation does not mean that every follow-up can be answered from history. The application must determine whether the requested data is already available.

### Example A: Existing data can be reused

```text
Turn 1: Show chickenpox cases in Accomack County from 2020 through 2024.
Turn 2: What about in 2024?
```

If the validated Turn 1 result already contains the 2024 row, the application may reuse it.

### Example B: A new database query is required

```text
Turn 1: Show chickenpox cases in Accomack County in 2023.
Turn 2: What about in 2024?
```

The 2024 value was not loaded in Turn 1. The application should retain the active dataset and location, update the year parameter, and query DuckDB again.

### Example C: The location changes

```text
Turn 1: Show chickenpox cases in Accomack County in 2024.
Turn 2: What about Fairfax County?
```

This is still the same task and dataset, but it requires a new database query with a different geography filter.

### Example D: A genuinely new topic

```text
Turn 1: Show chickenpox cases in Accomack County.
Turn 2: How many students are enrolled in James City County schools?
```

The router should select the education dataset, reset incompatible active filters, and make the new DuckDB result the primary source of truth. Previous health data may remain in conversation history, but it must not influence the answer.

## Recommended Turn-by-Turn Workflow

### Step 1: Normalize the user message

Remove only interface artifacts. Preserve meaningful values such as years, place names, comparison language, and negation.

### Step 2: Resolve pending clarification first

If `pending_clarification` is active, interpret the message as a clarification response before running normal routing. Reconstruct the request using `original_query` and the selected clarification value.

### Step 3: Classify the turn

Classify the message as a likely follow-up, new topic, or ambiguous request. This can use deterministic signals plus a small structured LLM classification call.

The classifier should return machine-readable output, for example:

```json
{
  "turn_type": "follow_up",
  "confidence": 0.91,
  "changed_fields": ["year"],
  "requested_values": {"year": 2024}
}
```

### Step 4: Run semantic routing with a relevance gate

Retrieve candidates, but do not automatically accept the first row. Apply a tested relevance threshold and ambiguity rule. Log the candidate scores and final routing decision for debugging.

### Step 5: Merge with structured active state

For a follow-up, inherit only compatible fields from the previous state. Explicit values in the new user message must override inherited values.

Example:

```text
Active state: Accomack County, chickenpox, 2023
New message: What about Fairfax in 2024?
Merged state: Fairfax County, chickenpox, 2024
```

### Step 6: Determine whether a new query is required

Reuse prior validated data only when it contains every requested field, geography, year, and comparison value. Otherwise, query DuckDB again.

### Step 7: Build bounded context

Construct the context from structured components:

1. Dataset identity and source metadata.
2. Applied filters.
3. Selected columns.
4. Complete result rows.
5. A compact summary of relevant prior turns.

Do not rely on blind character truncation. A 60,000-character substring may cut a JSON object or table row in half. Limit rows and columns first, serialize complete records, and then enforce a token-aware budget.

### Step 8: Generate and validate the answer

The LLM may explain and format the validated result, but it should not invent missing values. If the available data cannot answer the question, it should request clarification or state that an additional query is required.

### Step 9: Update state only after success

Update `active_state` only after routing and database execution succeed. A failed or ambiguous request should not overwrite the last valid state.

## Context and History Management

The proposed safeguards are useful but should be enforced in code rather than only described in the system prompt.

Recommended controls:

- One primary dataset per answer unless the user explicitly requests a cross-dataset comparison.
- A SQL row limit, with a clear message when results are truncated.
- Column selection based on the query plan rather than allowing the model to inspect all fields.
- Complete-record truncation instead of raw string truncation.
- A maximum number of recent conversational turns.
- A structured summary for older turns.
- Separate budgets for metadata, database results, and conversation history.
- Logging of dataset selection, filters, row count, and truncation decisions.

The size of one data block does not represent the total context size. In a stateful chat, previous prompts, responses, system instructions, and tool results also accumulate. Long-session testing is therefore required even when each individual query returns fewer than 3,000 tokens.

## Session Export and Import

If an imported session is expected to continue a conversation, exporting only the rendered HTML is insufficient. The application should save:

- A versioned session schema.
- The structured active state.
- Pending clarification state.
- Relevant chat turns or a validated conversation summary.
- Dataset identifiers and metadata references.
- The application/store version used to create the session.

On import, validate the schema and confirm that referenced datasets still exist. If model turns cannot be restored into `chat_obj`, the interface should clearly state that the transcript is view-only and that conversational memory has not been resumed.

## Current Implementation Notes

The registry-store update is moving in the right direction. It now preserves structured `dataset_id` and `metadata_path` fields and avoids reconstructing identifiers through path regular expressions.

However, the two chatbot files currently represent different architectures:

- `chatbot_prototype.R` still clones the chat object and clears its turns, so it remains stateless.
- `chatbot_test.R` uses the persistent chat object and is stateful.

The production behavior should be selected explicitly and implemented in one canonical application file. The stateful experiment should not be treated as complete until routing thresholds, database re-query logic, session restoration, and regression tests are added.

The current prototype also needs an export correction: `session_snapshot` is commented out while `write_json(session_snapshot, ...)` is still called. This will fail when a user downloads a session.

## Recommended Tests

Before replacing the existing behavior, add automated tests for at least the following cases:

1. Same dataset, same location, different year.
2. Same dataset, different location.
3. Same dataset, new comparison request.
4. Sudden change to an unrelated dataset.
5. Ambiguous city/county name followed by a one-word clarification.
6. A vague follow-up after several unrelated turns.
7. An irrelevant query that still receives top-k semantic candidates.
8. No sufficiently relevant dataset.
9. A requested year that is absent from the previously loaded rows.
10. A long conversation approaching the context budget.
11. Session export followed by import and a new follow-up question.
12. Database or routing failure without corruption of the last valid state.

For each test, verify:

- Selected dataset.
- Applied geography and year filters.
- Whether DuckDB was queried.
- Context row and column counts.
- Final active state.
- Whether the answer contains only values supported by the validated result.

## Final Recommendation

Proceed with a stateful LLM for conversational continuity, but do not rely on conversation history as the only memory mechanism. Replace the large response cache with a small structured state object, add a relevance gate to semantic routing, and explicitly decide whether every follow-up requires a new DuckDB query.

The architecture should follow this principle:

> Conversation history helps interpret the request; structured state and database results determine the facts.

Once routing thresholds, structured state, bounded context construction, session restoration, and regression tests are in place, the stateful approach should be more maintainable and reliable than the current pseudo-memory cache.
