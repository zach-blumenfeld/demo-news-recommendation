:use neo4j;
CREATE DATABASE mind;
:use mind

//create Constraints
CREATE CONSTRAINT userId_not_null ON (user:User) ASSERT user.userId IS NOT NULL;
CREATE CONSTRAINT userId_unique ON (user:User) ASSERT user.userId  IS UNIQUE;

CREATE CONSTRAINT news_id_not_null ON (news:News) ASSERT news.newsId IS NOT NULL;
CREATE CONSTRAINT news_id_unique ON (news:News) ASSERT news.newsId IS UNIQUE;

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
WHERE row.abstract IS NOT NULL
SET news.abstract = row.abstract
RETURN count(news);

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
