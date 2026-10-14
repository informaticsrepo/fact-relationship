# --- Set database and CDM schema here (edit the values and code in this section ---

myDbms<-'postgresql'
cdmDatabaseSchema <- "cdm"

# Setup you connection (e.g., using keyring credentials but you can use other methods)
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = myDbms,
  server = keyring::key_get("server"),
  user = keyring::key_get("user"),
  port = "5432", #comment out if port is not not needed 
  password = keyring::key_get("password")
)


# --- script starts here ----

conn <- DatabaseConnector::connect(connectionDetails)

# Count relationships by domain pair.
sql <- "
SELECT
  fr.domain_concept_id_1,
  c1.concept_name AS domain_concept_name_1,
  fr.domain_concept_id_2,
  c2.concept_name AS domain_concept_name_2,
  COUNT(*) AS cnt
FROM @cdm_database_schema.fact_relationship fr
INNER JOIN @cdm_database_schema.concept c1
  ON fr.domain_concept_id_1 = c1.concept_id
INNER JOIN @cdm_database_schema.concept c2
  ON fr.domain_concept_id_2 = c2.concept_id
GROUP BY
  fr.domain_concept_id_1,
  c1.concept_name,
  fr.domain_concept_id_2,
  c2.concept_name;
"
# Render, translate, and fetch into R.
domainRelationships <- DatabaseConnector::renderTranslateQuerySql(
  connection = conn,
  sql = sql,
  cdm_database_schema = cdmDatabaseSchema,
  snakeCaseToCamelCase = TRUE
)
DatabaseConnector::disconnect(conn)

# add percentage column 
counts <- as.numeric(domainRelationships$cnt)
totalCount <- sum(counts)
domainRelationships$percentage <- if (totalCount > 0) {
  round(100 * counts / totalCount, digits = 2)
} else {
  numeric(nrow(domainRelationships))
}

# drop the cnt collumn and keep domain labels and percentages.
domainRelationshipRelative <- domainRelationships[
  , c(
    "domainConceptId1",
    "domainConceptName1",
    "domainConceptId2",
    "domainConceptName2",
    "percentage"
  )
]
# Save CSV and preview five rows.
utils::write.csv(
  domainRelationshipRelative,
  file = "fact_relationships-aggregated-and-relative-data.csv",
  row.names = FALSE
)

#show preview of data
print(utils::head(domainRelationshipRelative, n = 5))
