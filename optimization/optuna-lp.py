from neo4j import GraphDatabase
import optuna
import textwrap
from argparse import ArgumentParser

def run(driver, query, params=None):
    # print(query)
    with driver.session() as session:
        if params is not None:
            print(params)
            return [r for r in session.run(query, params)]
        else:
            return [r for r in session.run(query)]


def clear_graph(driver, graphName):
    if run(driver, f"CALL gds.graph.exists('{graphName}') YIELD exists RETURN exists")[0].get("exists"):
        run(driver, f"CALL gds.graph.drop('{graphName}')")


def clear_model(driver, modelName):
    if run(driver, f"CALL gds.beta.model.exists('{modelName}') YIELD exists RETURN exists")[0].get("exists"):
        run(driver, f"CALL gds.beta.model.drop('{modelName}')")


def train_and_eval_lp_pipe(driver):
    def objective(params):
        # clear former assets
        clear_graph(driver, "lp-projection")
        clear_model(driver, "pipe")
        clear_model(driver, "model")

        # create graph
        run(driver, textwrap.dedent("""\
            CALL gds.graph.create(
              'lp-projection',
              {
                NewsWithContext:{properties:['wikiEmbedding']},
                WikiEntity:{properties:['wikiEmbedding']}
              },
              {
                TITLE_ABOUT:{
                  type:'TITLE_ABOUT',
                  orientation:'UNDIRECTED',
                  properties:['confidence']
                },
                ABSTRACT_ABOUT: {
                  type: 'ABSTRACT_ABOUT',
                  orientation: 'UNDIRECTED',
                  properties:  ['confidence']
                },
                SIMILAR:{
                  type:'SIMILAR',
                  orientation: 'UNDIRECTED'
                }
              }
            )""")
            )

        # fastRP
        run(driver, textwrap.dedent("""\
            CALL gds.fastRP.mutate('lp-projection', {
                mutateProperty: 'entityEmbedding',
                relationshipTypes: ['TITLE_ABOUT' , 'ABSTRACT_ABOUT'],
                normalizationStrength: $normalizationStrength,
                iterationWeights: $iterationWeights,
                featureProperties: ['wikiEmbedding'],
                embeddingDimension: $embeddingDimension,
                propertyRatio: $propertyRatio,
                randomSeed: 7474,
                relationshipWeightProperty: 'confidence',
                concurrency: 20
            })"""),
            params=params
            )

        # create pipeline
        run(driver, textwrap.dedent("""\
            CALL gds.alpha.ml.pipeline.linkPrediction.create('pipe')""")
            )

        run(driver, textwrap.dedent("""\
            CALL gds.alpha.ml.pipeline.linkPrediction.addFeature('pipe', 'l2', {
              nodeProperties: ['entityEmbedding']
            })""")
            )

        run(driver, textwrap.dedent("""\
            CALL gds.alpha.ml.pipeline.linkPrediction.configureSplit('pipe', {
              testFraction: 0.3,
              trainFraction: 0.7,
              validationFolds: 5
            })""")
            )

        run(driver, textwrap.dedent("""\
            CALL gds.alpha.ml.pipeline.linkPrediction.configureParams('pipe', [
              {
                penalty: 0.001,
                patience: 3,
                maxEpochs: 1000,
                tolerance: 0.0001
              }
            ])"""),
            params=params
            )

        # train and return
        result = run(driver, textwrap.dedent("""\
            CALL gds.alpha.ml.pipeline.linkPrediction.train( 'lp-projection', {
              modelName: 'model',
              pipeline: 'pipe',
              randomSeed: 7474,
              concurrency: 20,
              nodeLabels: ['NewsWithContext'],
              relationshipTypes: ['SIMILAR']
            }) YIELD modelInfo
            RETURN modelInfo.metrics.AUCPR.test AS testGraphScore, modelInfo.metrics.AUCPR.outerTrain AS trainGraphScore"""),
                     params=params
                     )
        print("test score: " + str(result[0].get("testGraphScore")))
        print("outer train score: " + str(result[0].get("trainGraphScore")))
        return result[0].get("trainGraphScore")

    return objective

def main():
    parser = ArgumentParser()
    parser.add_argument('--host', action='store', default="neo4j://localhost")
    parser.add_argument('--database', action='store', default="neo4j")
    parser.add_argument('--password', action='store', required=True)

    args = parser.parse_args()
    with GraphDatabase.driver(args.host, auth=(args.database, args.password)) as driver:
        objective = train_and_eval_lp_pipe(driver)
        initial_params = {
            'normalizationStrength': 0.0,
            'iterationWeight2': 1.0,
            'iterationWeight3': 1.0,
            'propertyRatio': 0.8,
            'embeddingDimension': 132,
            #'penalty': 1e-3,
        }


        def optuna_objective(trial):
            # [0, 0, 1, 3.14]k
            iteration_weight2 = trial.suggest_float("iteration_weight2", 0.01, 1)
            iteration_weight3 = trial.suggest_float("iteration_weight3", 0.01, 1)
            params = {
                "normalizationStrength": trial.suggest_float("normalizationStrength", -1, 1),
                "iterationWeights": [0.0, iteration_weight2, iteration_weight3],
                "propertyRatio": trial.suggest_float("propertyRatio", 0.001, 1.0, log=True),
                "embeddingDimension": trial.suggest_int("embeddingDimension", 64, 300, log=True),
               # "penalty": trial.suggest_float("penalty", 1e-4, 1e3, log=True)
            }
            return objective(params)


        study = optuna.create_study(direction='maximize')
        study.enqueue_trial(initial_params)
        study.optimize(optuna_objective, n_trials=100)

if __name__ == "__main__":
    main()
# python ml-benchmark.py --password=$CORA_AURA_PASSWORD --host=$CORA_AURA_HOST
