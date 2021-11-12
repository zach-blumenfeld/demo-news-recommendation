//1 add lucene index
CREATE FULLTEXT INDEX titlesAndAbstractsEnglish FOR (n:News) ON EACH [n.title, n.abstract]
OPTIONS {indexConfig: {`fulltext.analyzer`: 'english', `fulltext.eventually_consistent`: true}}

//2 example search - filtered & ordered by search relevance of news article
CALL db.index.fulltext.queryNodes("titlesAndAbstractsEnglish", "adorable puppies") YIELD node, score
RETURN node.title AS title, node.url AS url, score AS searchScore

//3 graph projection for calculating PageRank
CALL gds.graph.create(
  'search-projection',
  ['User', 'RecentNews'],
  {
    CLICKED:{
      type:'CLICKED',
      orientation:'UNDIRECTED'
    }
  }
) YIELD nodeCount, relationshipCount, createMillis;

//4 calculate PageRank
CALL gds.pageRank.write('search-projection', {
  writeProperty: 'pageRank',
  scaler: "MinMax",
  maxIterations: 100,
  concurrency: 20
}) YIELD didConverge, ranIterations, centralityDistribution, nodePropertiesWritten, computeMillis, writeMillis;

//5 example search - filtered by search term and ordered by popularity
CALL db.index.fulltext.queryNodes("titlesAndAbstractsEnglish", "adorable puppies") YIELD node, score
RETURN node.title AS title, node.url AS url, score AS searchScore,
node.pageRank AS graphScore ORDER BY graphScore DESC;