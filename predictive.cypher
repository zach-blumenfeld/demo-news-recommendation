CALL gds.graph.create(
  'lp-projection',
  {
    NewsWithContext:{properties:['wikiEmbedding']},
    EntityWithContext:{properties:['wikiEmbedding']}
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

CALL gds.fastRP.mutate(
  'lp-projection',
  {
    mutateProperty: 'entityEmbedding',
    relationshipTypes: ['TITLE_ABOUT' , 'ABSTRACT_ABOUT'],
    embeddingDimension: 100,
    propertyRatio: 100.0/100.0,
    concurrency: 20,
  //concurrency: 4,
    featureProperties: ['wikiEmbedding'],
    randomSeed: 7474,
    relationshipWeightProperty: 'confidence'
  }
) YIELD nodePropertiesWritten, computeMillis;

CALL gds.alpha.ml.pipeline.linkPrediction.create('pipe');

//add L2 link feature
CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('pipe', 'l2', {
  nodeProperties: ['entityEmbedding']
}) YIELD featureSteps;


//configure data splitting
CALL gds.alpha.ml.pipeline.linkPrediction.configureSplit('pipe', {
  testFraction: 0.3,
  trainFraction: 0.7,
  validationFolds: 5
}) YIELD splitConfig;

CALL gds.alpha.ml.pipeline.linkPrediction.configureParams('pipe', [
  {
    penalty: 0.01,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.00001
  },
  {
    penalty: 1.0,
    patience: 3,
    maxEpochs: 1000,
    tolerance: 0.00001
  }
]) YIELD parameterSpace;


//CALL gds.alpha.ml.pipeline.linkPrediction.train( 'lp-projection', {
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

//Lets try with the entity embeddings.  We will need to impute something though for the news articles...
CALL gds.alpha.ml.pipeline.linkPrediction.predict.mutate('lp-projection', {
  modelName: 'news-similarity-model',
  mutateRelationshipType: 'SIMILAR_PREDICTED',
  nodeLabels: ['NewsWithContext'],
  relationshipTypes: ['SIMILAR'],
  topN: 10,
  threshold: 0.0,
  concurrency: 20
});

//write predicted relationships back to DB and delete duplicates
CALL gds.graph.writeRelationship('lp-projection', 'SIMILAR_PREDICTED', 'probability');
// undirected relationships will have a relationship for each direction, we only need one
MATCH (n:News)-[r:SIMILAR_PREDICTED]->(m:News) WHERE id(n) < id(m) DELETE r;

//Visualize Predicted Entity Links
MATCH (n:News)-[s:SIMILAR_PREDICTED]-(m:News) WITH *
OPTIONAL MATCH (n)-[r1:TITLE_ABOUT|ABSTRACT_ABOUT]->(w:WikiEntity)<-[r2:TITLE_ABOUT|ABSTRACT_ABOUT]-(n2:News) WITH *
OPTIONAL MATCH (m)-[r3:TITLE_ABOUT|ABSTRACT_ABOUT]->(w:WikiEntity)<-[r4:TITLE_ABOUT|ABSTRACT_ABOUT]-(m2:News)
RETURN *


