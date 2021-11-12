//1 set time decay
MATCH(:User)-[c:CLICKED|DID_NOT_CLICK]->()
WITH apoc.date.convert(max(c.impressionTime).epochSeconds,'seconds','days') as maxDays
MATCH(:User)-[c:CLICKED|DID_NOT_CLICK]->()
SET c.timeWeight = exp(-0.1*(maxDays - apoc.date.convert(c.impressionTime.epochSeconds,'seconds','days')));

//2 approximate News publish time with minimum impression time. Label news used in impressions as 'RecentNews'
MATCH(n:News)<-[c:CLICKED|DID_NOT_CLICK]-()
SET n.approxTime = min(c.impressionTime)
SET n:RecentNews;

//3 create graph projection for subsampling News nodes
CALL gds.graph.create(
  'mind-projection',
  ['User', 'RecentNews', 'WikiEntity'],
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

//4 Weakly Connected Components (WCC) of click relationships
CALL gds.wcc.write('mind-projection', {
  writeProperty: 'clickComponentId',
  nodeLabels:['RecentNews', 'User'],
  relationshipTypes: ['CLICKED']
}) YIELD componentCount, nodePropertiesWritten, writeMillis, computeMillis;

//5 Weakly Connected Components (WCC) of title/abstract about relationships
CALL gds.wcc.write('mind-projection', {
  writeProperty: 'entityComponentId',
  nodeLabels:['RecentNews', 'EntityWithContext'],
  relationshipTypes: ['TITLE_ABOUT', 'ABSTRACT_ABOUT']
}) YIELD componentCount, nodePropertiesWritten, writeMillis, computeMillis;

//6 view well connected click components(s)
MATCH(n:RecentNews)
WITH DISTINCT n.clickComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;

//7 view well connected news with context components(s)
MATCH(n:RecentNews)
WITH DISTINCT n.entityComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
RETURN distinct componentSize, count(*) as numberOfComponents
  ORDER BY componentSize;

//8 label well connected news
MATCH(n:RecentNews)
WITH DISTINCT n.clickComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
WITH collect(componentId) AS bigComponents
MATCH(n:RecentNews) WHERE n.clickComponentId IN  bigComponents
SET n:ConnectedNews;

//9 label news with well connected context
MATCH(n:RecentNews)
WITH DISTINCT n.entityComponentId AS componentId, count(DISTINCT n) AS componentSize
  WHERE componentSize > 10
WITH collect(componentId) AS bigComponents
MATCH(n:RecentNews) WHERE n.entityComponentId IN bigComponents
SET n:NewsWithContext;

