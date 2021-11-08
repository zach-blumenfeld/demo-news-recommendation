:use neo4j;
CREATE DATABASE mind;
:use mind

//create Constraints
CREATE CONSTRAINT userId_not_null ON (user:User) ASSERT user.userId IS NOT NULL;
CREATE CONSTRAINT userId_unique ON (user:User) ASSERT user.userId  IS UNIQUE;

CREATE CONSTRAINT news_id_not_null ON (news:News) ASSERT news.newsId IS NOT NULL;
CREATE CONSTRAINT news_id_unique ON (news:News) ASSERT news.newsId IS UNIQUE;

CREATE CONSTRAINT wiki_id_not_null ON (entity:WikiEntity) ASSERT entity.wikidataId IS NOT NULL;
CREATE CONSTRAINT wiki_id_unique ON (entity:WikiEntity) ASSERT entity.wikidataId IS UNIQUE;

//create b-tree indexes
CREATE INDEX clicked_impression_index FOR ()-[r:CLICKED]-() ON (r.impressionId);
CREATE INDEX clicked_impression_time_index FOR ()-[r:CLICKED]-() ON (r.impressionTime);
CREATE INDEX clicked_split_set_index FOR ()-[r:CLICKED]-() ON (r.splitSet);

CREATE INDEX did_not_click_impression_index FOR ()-[r:DID_NOT_CLICK]-() ON (r.impressionId);
CREATE INDEX did_not_click_impression_time_index FOR ()-[r:DID_NOT_CLICK]-() ON (r.impressionTime);
CREATE INDEX did_not_click_split_set_index FOR ()-[r:DID_NOT_CLICK]-() ON (r.splitSet);

CREATE INDEX historic_click_split_set_index FOR ()-[r:HISTORICALLY_CLICKED]-() ON (r.splitSet);

//load users
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (user:User {userId:row.userId})
RETURN count(user);

//load news
LOAD CSV WITH HEADERS FROM 'file:///news.csv' AS row
MERGE (news:News {
  newsId: row.newsId,
  category: row.category,
  subCategory: row.subCategory,
  title: row.title,
  url: row.url})
WITH row, news
WHERE row.abstract IS NOT null
SET news.abstract = row.abstract
RETURN count(news);

//load wiki entities
LOAD CSV WITH HEADERS FROM 'file:///entities.csv' AS row
MERGE (entity:WikiEntity {
    wikidataId: row.WikidataId,
    wikiLabel: row.Label,
    wikiType: row.Type,
    url: 'https://www.wikidata.org/wiki/' + row.WikidataId
  })
RETURN count(entity);

//load wiki entity embeddings
LOAD CSV WITH HEADERS FROM 'file:///entities-embedding.csv' AS row
MATCH (entity:WikiEntity {wikidataId: row.WikidataId})
SET entity.wikiEmbedding = toFloatList(split(row.entityEmbedding, ';'))
RETURN count(entity);

//load historic clicks
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 'file:///historic-clicks.csv' AS row
MATCH(user:User {userId: row.userId})
MATCH(news:News {newsId: row.newsId})
MERGE (user)-[r:HISTORICALLY_CLICKED {
  splitSet: row.splitSet
}]->(news)
RETURN count(r);

//load clicks
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 'file:///clicks.csv' AS row
MATCH(user:User {userId: row.userId})
MATCH(news:News {newsId: row.newsId})
MERGE (user)-[r:CLICKED {
  splitSet: row.splitSet,
  impressionId: row.impressionId,
  impressionTime: datetime({ epochSeconds:apoc.date.parse(row.time, 's', 'yyyy-MM-dd HH:mm:ss')})
}]->(news)
RETURN count(r);

//load did not click events
:auto USING PERIODIC COMMIT 10000
LOAD CSV WITH HEADERS FROM 'file:///did-not-click.csv' AS row
MATCH(user:User {userId: row.userId})
MATCH(news:News {newsId: row.newsId})
MERGE (user)-[r:DID_NOT_CLICK {
  splitSet: row.splitSet,
  impressionId: row.impressionId,
  impressionTime: datetime({ epochSeconds:apoc.date.parse(row.time, 's', 'yyyy-MM-dd HH:mm:ss')})
}]->(news)
RETURN count(r);

//title about
LOAD CSV WITH HEADERS FROM 'file:///title-entity-rel.csv' AS row
MATCH(news:News {newsId: row.newsId})
MATCH(entity:WikiEntity {wikidataId: row.WikidataId})
MERGE (news)-[r:TITLE_ABOUT{ confidence: toFloat(row.Confidence)}]->(entity)
RETURN count(r);

//abstract about
LOAD CSV WITH HEADERS FROM 'file:///abstract-entity-rel.csv' AS row
MATCH(news:News {newsId: row.newsId})
MATCH(entity:WikiEntity {wikidataId: row.WikidataId})
MERGE (news)-[r:ABSTRACT_ABOUT{ confidence: toFloat(row.Confidence)}]->(entity)
RETURN count(r);

CREATE FULLTEXT INDEX titlesAndAbstractsEnglish FOR (n:News) ON EACH [n.title, n.abstract]
OPTIONS {indexConfig: {`fulltext.analyzer`: 'english', `fulltext.eventually_consistent`: true}}

