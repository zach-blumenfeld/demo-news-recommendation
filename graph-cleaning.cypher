//set time decay
MATCH(:User)-[c:CLICKED|DID_NOT_CLICK]->()
WITH apoc.date.convert(max(c.impressionTime).epochSeconds,'seconds','days') as maxDays
MATCH(:User)-[c:CLICKED|DID_NOT_CLICK]->()
SET c.timeWeight = exp(-0.1*(maxDays - apoc.date.convert(c.impressionTime.epochSeconds,'seconds','days')))

//Use an alternate label to rule out null wiki embeddings in following analysis
MATCH(w:WikiEntity) WHERE w.wikiEmbedding IS NOT NULL
SET w:EntityWithContext


CALL gds.graph.create(
  'mind-projection',
  ['User', 'News', 'EntityWithContext'],
  {
    CLICKED:{
              type:'CLICKED',
              orientation:'UNDIRECTED'
            },
    HISTORICALLY_CLICKED:{
              type:'HISTORICALLY_CLICKED',
              orientation: 'UNDIRECTED'
            },
    TITLE_ABOUT:{
              type:'TITLE_ABOUT',
              orientation:'UNDIRECTED',
              properties:['confidence']
            },
    ABSTRACT_ABOUT:{
              type:'ABSTRACT_ABOUT',
              orientation: 'UNDIRECTED',
              properties:['confidence']
            }
  }
) YIELD nodeCount, relationshipCount, createMillis;

CALL gds.wcc.write('mind-projection', {
  writeProperty: 'clickComponentId',
  nodeLabels:['News', 'User'],
  relationshipTypes: ['CLICKED']
}) YIELD componentCount, nodePropertiesWritten, writeMillis, computeMillis;

CALL gds.wcc.write('mind-projection', {
  writeProperty: 'entityComponentId',
  nodeLabels:['News', 'EntityWithContext'],
  relationshipTypes: ['TITLE_ABOUT', 'ABSTRACT_ABOUT']
}) YIELD componentCount, nodePropertiesWritten, writeMillis, computeMillis;

//good click components
MATCH(n:News)
WITH DISTINCT n.clickComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;

//good entity components
MATCH(n:News)
WITH DISTINCT n.entityComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;


//good click components
MATCH(n:News)
WITH DISTINCT n.clickComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;

//good entity components
MATCH(n:News)
WITH DISTINCT n.entityComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;

//label connected news
MATCH(n:News)
WITH DISTINCT n.clickComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
WITH collect(componentId) AS bigComponents
MATCH(n:News) WHERE n.clickComponentId IN  bigComponents
SET n:ConnectedNews;

//label news with context, require a recent user click to make sure the news is recent.
MATCH(n:News)<-[:CLICKED]-() WITH n
WITH DISTINCT n.entityComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
WITH collect(componentId) AS bigComponents
MATCH(n:News) WHERE n.entityComponentId IN  bigComponents
SET n:NewsWithContext;
