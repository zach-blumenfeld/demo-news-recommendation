//1 create relationship to represent high quality similarities
MATCH(n:ConnectedNews)-[r:USERS_ALSO_LIKED]->(m:ConnectedNews)
WHERE r.score >= 0.8
MERGE(n)-[s:SIMILAR {score: r.score}]->(m)
RETURN count(s);

//2 create graph projection
CALL gds.graph.create(
  'lp-projection',
  {
    NewsWithContext:{properties:['wikiEncoding']},
    WikiEntity:{properties:['wikiEncoding']}
  },
  {
    TITLE_ABOUT:{
      type:'TITLE_ABOUT',
      orientation:'UNDIRECTED',
      properties:['confidence']
    },
    ABSTRACT_ABOUT: {
      type: 'ABSTRACT_ABOUT',
      orientation: 'UNDIRECTED',
      properties:  ['confidence']
    },
    SIMILAR:{
      type:'SIMILAR',
      orientation: 'UNDIRECTED'
    }
  }
) YIELD nodeCount, relationshipCount, createMillis;

//3 generate embeddings for link predictions.  To optimize parameters, see optuna-lp.py script
CALL gds.fastRP.mutate(
  'lp-projection',
  {
    mutateProperty: 'entityEmbedding',
    relationshipTypes: ['TITLE_ABOUT' , 'ABSTRACT_ABOUT'],
    embeddingDimension: 266,
    propertyRatio: 0.1,
    concurrency: 20,
    featureProperties: ['wikiEncoding'],
    randomSeed: 7474,
    relationshipWeightProperty: 'confidence',
    normalizationStrength: 0.61,
    iterationWeights: [0.0, 0.24, 0.71]
  }
) YIELD nodePropertiesWritten, computeMillis;

//4 instantiate pipeline
CALL gds.alpha.ml.pipeline.linkPrediction.create('pipe');

//5 add L2 link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('pipe', 'l2', {
  nodeProperties: ['entityEmbedding']
}) YIELD featureSteps;

//6 configure data splitting
CALL gds.alpha.ml.pipeline.linkPrediction.configureSplit('pipe', {
  testFraction: 0.3,
  trainFraction: 0.7,
  validationFolds: 5
}) YIELD splitConfig;

//7 configure parameters.  To optimize hyper-parameters see
CALL gds.alpha.ml.pipeline.linkPrediction.configureParams('pipe', [
  {
    penalty: 2.15,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.0001
  },
  {
    penalty: 0.001,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.00001
  }
]) YIELD parameterSpace;

//9 train LP model
CALL gds.alpha.ml.pipeline.linkPrediction.train( 'lp-projection', {
  modelName: 'news-similarity-model',
  pipeline: 'pipe',
  randomSeed: 7474,
  concurrency: 4,
  nodeLabels: ['NewsWithContext'],
  relationshipTypes: ['SIMILAR'],
  negativeClassWeight: 1.0
}) YIELD modelInfo
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore,
  modelInfo.metrics.AUCPR.test AS testGraphScore;

//10 Predict top 100 News Similarities (note: This step can 30 min or more to complete)
CALL gds.alpha.ml.pipeline.linkPrediction.predict.mutate('lp-projection', {
  modelName: 'news-similarity-model',
  mutateRelationshipType: 'SIMILAR_PREDICTED',
  nodeLabels: ['NewsWithContext'],
  relationshipTypes: ['SIMILAR'],
  topN: 10,
  threshold: 0.0,
  concurrency: 20
});

//11 write predicted relationships back to DB and delete duplicates
CALL gds.graph.writeRelationship('lp-projection', 'SIMILAR_PREDICTED', 'probability');
//undirected relationships will have a relationship for each direction, we only need one
MATCH (n:News)-[r:SIMILAR_PREDICTED]->(m:News) WHERE id(n) < id(m) DELETE r;

//12 visualize new predictions
MATCH (n:News)-[r:SIMILAR_PREDICTED]->(m:News)  return *;

//13 return updated ranked recommendations for User who clicked on Ukraine news
MATCH(u:User {userId: "U7822"})-->(n:News)
WITH collect(id(n)) AS clickedNewsIds
//Get Similar News according to our KNN predictions and exclude previously clicked articles
MATCH (clickedNews)-[s:SIMILAR_PREDICTED|SIMILAR]-(similarNews:News)
WHERE id(clickedNews) IN clickedNewsIds AND NOT id(similarNews) IN clickedNewsIds
//approx. scoring with model mix
WITH *, CASE WHEN s.probability IS NOT NULL THEN 1.0 ELSE s.score END AS relScore,
CASE WHEN s.probability IS NOT NULL THEN 1 ELSE 0 END AS predicted
//aggregate and return ordered result
RETURN DISTINCT similarNews.newsId as newsId, similarNews.title AS title, similarNews.approxTime AS time,
                sum(relScore) AS totalScore, min(predicted) AS wasPredicted ORDER BY totalScore DESC


