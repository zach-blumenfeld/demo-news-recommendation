//1 create graph projection for KNN
CALL gds.graph.create(
  'cf-projection',
  ['ConnectedNews', 'User'],
  {
    CLICKED:{
      type:'CLICKED',
      orientation:'UNDIRECTED',
      properties:['timeWeight']
    }
  }
) YIELD nodeCount, relationshipCount, createMillis;

//2 create embeddings for similarity calculations
CALL gds.fastRP.mutate(
  'cf-projection',
  {
    nodeLabels: ['ConnectedNews', 'User'],
    relationshipTypes: ['CLICKED'],
    relationshipWeightProperty: 'timeWeight',
    mutateProperty: 'CFembedding',
    embeddingDimension: 64,
    concurrency: 20,
    randomSeed: 7474
  }
) YIELD nodePropertiesWritten, computeMillis;

//3 use K-Nearest Neighbor to draw recommended relationships
CALL gds.beta.knn.write('cf-projection', {
  nodeLabels: ['ConnectedNews'],
  concurrency: 20,
  nodeWeightProperty: 'CFembedding',
  writeRelationshipType: 'USERS_ALSO_LIKED',
  writeProperty: 'score'
});

//4 recommend News for specific User
MATCH(u:User {userId: "U91836"})-[:CLICKED]->(n:News)
WITH collect(id(n)) AS clickedNewsIds
//get similar News according to KNN and exclude previously clicked news
MATCH (clickedNews)-[s:USERS_ALSO_LIKED]->(similarNews:News)
  WHERE id(clickedNews) IN clickedNewsIds AND NOT id(similarNews) IN clickedNewsIds
//aggregate and return ranked results
RETURN DISTINCT similarNews.newsId as newsId, similarNews.title AS title, similarNews.approxTime AS time,
                sum(s.score) AS totalScore ORDER BY totalScore DESC;
