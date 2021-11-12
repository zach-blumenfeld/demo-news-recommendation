# Demo: Exploring News Recommendation With Neo4j GDS
Demo to explore how Neo4j & Graph Data Science (GDS) functionality, including Embeddings, K-Nearest Neighbor (KNN), 
Link Prediction (LP) Pipelines, and more can be used for news recommendation. This demo uses a real-world dataset described in the [Source Dataset](#sd) section below. 

To run the demo yourself, you first need to format and ingest the data into Neo4j as described in 
[Data Preparation and Ingest](#dpi). Once that is done you can run the Cypher and GDS steps described in the 
[Running the Analysis](#a) section. Please also  check the [Prerequisites](#prereqs) 
for proper software and versioning. 

## <a id="prereqs">Prerequisites</a>
- Neo4j Desktop (or other on-prem server installation) with Neo4j>=4.3.x 
- Graph Data Science (GDS) Library >=1.8
- Notebook uses Python=3.9.7

## <a id="dpi">Data Preparation and Ingest</a>

### <a id="sd">Source Dataset</a>
We will use the Microsoft [MIND-Small Dataset](https://msnews.github.io/#:~:text=name%20this%20dataset-,MIND-small,-.%20The%20training%20and)
which is a sample of anonymized users and their click behaviors on the Microsoft News website [[1]](#1).

### Directions for Creating the Neo4j Graph
1. Download the MIND-small dataset (both training and validation), unzip and place in a subdirectory named `./data`
2. Run the `data-prep-and-ingest/prepare-data.ipynb` notebook to prepare the data for Neo4j ingest.
3. Run the commands in the `data-prep-and-ingest/ingest.cypher`. These commands are best submitted sequentially,
either through the Neo4j Browser, command line, or via your choice driver. 

## <a id="a">Running the Analysis</a>
Once the data is loaded, the demo can be run via the scripts in the `analysis` directory. Below are the scripts, in order
1. `step-0-data-profiling.cypher`: Quick commands to understand Schema, indexes, and aggregate stats for the graph.
2. `step-1-data-preperation.cypher`: Data cleaning and formatting tasks .
3. `step-2-search.cypher`: (Optional) Leverage Lucene based full-text index and PageRank for search       
4. `step-3-collab-filtering.cypher`: News Recommendation with Collaborative Filtering. Predict user preferences with Unsupervized ML
5. `step-4-link-prediction.cypher`:  Use Link Prediction (Supervised ML) to Predict future user preferences based on news context.
6. `step-5-clean-up.cypher`: Script to clean up properties, labels, relationships, projections, and models generated from analysis.

## References
<a id="1">[1]</a>
Fangzhao Wu, Ying Qiao, Jiun-Hung Chen, Chuhan Wu, Tao Qi, Jianxun Lian, Danyang Liu, Xing Xie, Jianfeng Gao,
 Winnie Wu and Ming Zhou. MIND: A Large-scale Dataset for News Recommendation. ACL 2020.


