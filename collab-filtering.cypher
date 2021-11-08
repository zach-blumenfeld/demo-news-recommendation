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


//create KNN with similarity via embeddings
CALL gds.fastRP.mutate(
  'cf-projection',
  {
    nodeLabels: ['ConnectedNews', 'User'],
    relationshipTypes: ['CLICKED'],
    relationshipWeightProperty: 'timeWeight',
    mutateProperty: 'CFembedding',
    embeddingDimension: 64,
    concurrency: 20,
    //concurrency: 4,
    randomSeed: 7474
  }
) YIELD nodePropertiesWritten, computeMillis;

CALL gds.beta.knn.write('cf-projection', {
  nodeLabels: ['ConnectedNews'],
  concurrency: 20,
  //concurrency: 4,
  nodeWeightProperty: 'CFembedding',
  writeRelationshipType: 'USERS_ALSO_CLICKED_ON',
  writeProperty: 'score'
});

MATCH(n:News)-[r:USERS_ALSO_CLICKED_ON]->(m:News)
WHERE r.score >= 0.9
MERGE(n)-[s:SIMILAR {score: r.score}]->(m)
RETURN count(s)

//Get News for Specific User
MATCH(u:User {userId: "U91836"})-[:CLICKED]->(n:News)
WITH collect(id(n)) AS clickedNewsIds
//Get Similar News according to our KNN predictions and exclude previously clicked articles
MATCH (clickedNews)-[s:SIMILAR]->(similarNews:News)
  WHERE id(clickedNews) IN clickedNewsIds AND NOT id(similarNews) IN clickedNewsIds
WITH DISTINCT similarNews, similarNews.newsId as newsId, similarNews.title AS title, sum(s.score) AS totalScore ORDER BY totalScore DESC
OPTIONAL MATCH (similarNews)<-[c:CLICKED|DID_NOT_CLICK]-()
RETURN newsId, title, totalScore, min(c.impressionTime) AS time ORDER BY totalScore DESC

MATCH(u:User {userId: "U91836"})-[:CLICKED]->(n:News)
WITH collect(id(n)) AS clickedNewsIds
//Get Similar News according to our KNN predictions and exclude previously clicked articles
MATCH (clickedNews)-[s:SIMILAR]->(similarNews:News)<-[c:CLICKED|DID_NOT_CLICK]-()
WHERE id(clickedNews) IN clickedNewsIds AND NOT id(similarNews) IN clickedNewsIds
RETURN DISTINCT similarNews.newsId as newsId, similarNews.title AS title, min(c.impressionTime) AS time,
                sum(s.score) AS totalScore ORDER BY totalScore DESC
//["U91836", "U73700"]


