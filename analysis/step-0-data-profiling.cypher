//1 Visualize Schema
CALL db.schema.visualization();

//2 List Indexes
SHOW INDEXES;

//3 Aggregate Stats
CALL apoc.meta.stats() YIELD labels, relTypesCount;
