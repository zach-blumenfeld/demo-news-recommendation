# Demo: Exploring Embeddings and News Recommendation With Neo4j GDS
Demo to explore Neo4j & Graph Data Science (GDS) functionality with a focus on Embeddings, including a 
Search Recommendation example that leverages Collaborative Filtering. 

This demo uses the Microsoft [MIND-Small Dataset](https://msnews.github.io/#:~:text=name%20this%20dataset-,MIND-small,-.%20The%20training%20and)
which is a sample of anonymized users and their click behaviors on the Microsoft News website [[1]](#1).

To run the demo yourself, you first need to format and ingest the data into Neo4j following the
`prepare-and-load-data.ipynb` notebook. 

Once that is done you can run the following Embedding examples:

1. `fastrp-tsne-visualization.ipynb`: visualize fastRP embeddings structure with News categories 
2. `node2vec-example.cypher`: example of node2vec embedding in Neo4j Browser
3. `graphsage-example.cypher`: example of graphsage embedding in Neo4j Browser

And the search recommendation example that leverages Collaborative Filtering:  __(TK):__ `collab-filtering-example.ipynb`.

## Prerequisites
- Neo4j >= 4.3.x. This notebook was tested with [Neo4j Desktop](https://neo4j.com/download-center/#desktop) 
and should work for other on-prem installations.
- [APOC library](https://neo4j.com/labs/apoc/4.3/installation/).  This project was tested with APOC 4.3. 
- [Graph Data Science (GDS) Library](https://neo4j.com/docs/graph-data-science/current/installation/) >=1.7.2
- Notebooks tested with Python=3.8


## Collaborative Filtering
[Collaborative Filtering (CF)](https://en.wikipedia.org/wiki/Collaborative_filtering) is a technique used by recommender 
systems. CF is used to make automatic predictions for a user’s preferences based on the activity of other users with 
similar interests. For the MIND graph, common interests translate to “co-click” relationships between news articles.

Graph is well suited for applying CF as the relationships between user's preferences is baked into the data model and 
basic forms of CF are easily accomplished with simple graph traversals. in `collab-filtering-example.ipynb` we show
how CF can be scaled using FastRP embeddings in combination with K-nearest Neighbors (KNN) to reduce the dimentionalty 
of the problem while identifying similar news articles. 

## References
<a id="1">[1]</a>
Fangzhao Wu, Ying Qiao, Jiun-Hung Chen, Chuhan Wu, Tao Qi, Jianxun Lian, Danyang Liu, Xing Xie, Jianfeng Gao,
 Winnie Wu and Ming Zhou. MIND: A Large-scale Dataset for News Recommendation. ACL 2020.


