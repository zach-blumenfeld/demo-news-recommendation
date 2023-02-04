//1 projection
CALL gds.graph.create(
    'mind-projection',
    ['*'],
    {
        CLICKED:{orientation:'UNDIRECTED'},
        HISTORICALLY_CLICKED:{orientation: 'UNDIRECTED'},
        BELONGS_TO_SUBCATEGORY:{orientation: 'UNDIRECTED'},
        SUBCATEGORY_OF:{orientation: 'UNDIRECTED'},
        ABSTRACT_ABOUT:{orientation: 'UNDIRECTED'},
        TITLE_ABOUT:{orientation: 'UNDIRECTED'}
    },
    {nodeProperties: {wikiEncoding: {defaultValue: [i IN range(1,100) | 0.0]}}}
) YIELD nodeCount, relationshipCount, createMillis

//2 nodeToVec Embedding
CALL gds.beta.node2vec.write(
    'mind-projection',
    {
        embeddingDimension: 128,
        walkLength:6,
        walksPerNode:6,
        writeProperty: 'ntvEmbedding',
        randomSeed: 7474
    }
) YIELD nodeCount, nodePropertiesWritten, computeMillis

//3 show results
MATCH (n:News)
RETURN n.newsId as newsId, n.category + ': ' + n.title AS summary,
n.category AS category, n.ntvEmbedding AS ntvEmbedding

//4 clean up
MATCH (n:News) REMOVE n.ntvEmbedding;
CALL gds.graph.drop('mind-projection');