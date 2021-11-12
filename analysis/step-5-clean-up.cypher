//remove cleanup assets
MATCH(w:EntityWithContext) REMOVE w:EntityWithContext;
CALL gds.graph.drop('mind-projection');
MATCH(n:NewsWithContext) REMOVE n:NewsWithContext;
MATCH(n:ConnectedNews) REMOVE n:ConnectedNews;
MATCH(n) REMOVE n.clickComponentId;
MATCH(n) REMOVE n.entityComponentId;

//remove search assets
DROP INDEX titlesAndAbstractsEnglish;
CALL gds.graph.drop('search-projection');
MATCH(n) REMOVE n.pageRank;

//remove cf assets
MATCH(:User)-[c:CLICKED|DID_NOT_CLICK]->() REMOVE c.timeWeight;
CALL gds.graph.drop('cf-projection');
MATCH(:News)-[s:SIMILAR|USERS_ALSO_CLICKED_ON]->() DELETE s;

//remove lp assets
CALL gds.graph.drop('lp-projection');
CALL gds.beta.model.drop('news-similarity-model');
CALL gds.beta.model.drop('pipe');
MATCH(:News)-[s:SIMILAR_PREDICTED]->() DELETE s;