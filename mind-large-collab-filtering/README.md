# News Recommendations on Microsoft MIND Large
This folder holds an example recommender systems workflow, a variant of Collaborative Filter (CF), on the Microsoft [MIND-Large Dataset](https://msnews.github.io/). A blog explaining this analysis in detail can be found [here](https://neo4j.com/developer-blog/exploring-practical-recommendation-systems-in-neo4j/).

- `practical-graph-recommendation-cf-example.ipynb` contains the workflow on GDS 1.8 and aligns directly with the blog
- `gds-2-practical-graph-recommendation-cf-example.ipynb` contains the same analysis but updated to work with GDS 2.0 and the [GDS Python client](https://pypi.org/project/graphdatascience/).
- `prepare-and-load-data.ipynb` contains code for loading the data into Neo4j from the source provided by Microsoft
