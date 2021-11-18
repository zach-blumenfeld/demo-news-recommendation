//1 projection
CALL gds.graph.create(
  'mind-gs-projection',
  {
    User: {},
    Category: {},
    Subcategory: {},
    WikiEntity: {properties: {wikiEncoding: {defaultValue: [i IN range(1,100) | 0.0]}}},
    News: {}
  },
  {
    CLICKED:{orientation:'UNDIRECTED'},
    HISTORICALLY_CLICKED:{orientation: 'UNDIRECTED'},
    BELONGS_TO_SUBCATEGORY:{orientation: 'UNDIRECTED'},
    SUBCATEGORY_OF:{orientation: 'UNDIRECTED'},
    ABSTRACT_ABOUT:{orientation: 'UNDIRECTED'},
    SUBCATEGORY_OF:{orientation: 'UNDIRECTED'}
  }
) YIELD nodeCount, relationshipCount, createMillis

//2 train graphSage - Note this can take ~ 10 minutes or longer to complete
CALL gds.beta.graphSage.train(
  'mind-gs-projection',
  {
    modelName: 'graphSage',
    featureProperties: ['wikiEncoding'],
    aggregator: 'mean',
    activationFunction: 'sigmoid',
    projectedFeatureDimension: 10,
    sampleSizes: [25, 10],
    tolerance: 0.001,
    searchDepth: 5,
    embeddingDimension: 128
  }
)

//3 write graphSage embeddings
CALL gds.beta.graphSage.write(
  'mind-gs-projection',
  {
    writeProperty: 'gsEmbedding',
    modelName: 'graphSage'
  }
) YIELD nodeCount, nodePropertiesWritten

//4 show results
MATCH (n:News)
RETURN n.newsId as newsId, n.category + ': ' + n.title AS summary,
n.category AS category, n.gsEmbedding AS gsEmbedding

//5 clean up
MATCH (n:News) REMOVE n.gsEmbedding;
CALL gds.beta.model.drop('graphSage');
CALL gds.graph.drop('mind-gs-projection');