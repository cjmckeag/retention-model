# retention-model
From my tenure with the Sacramento Kings: a predictive model that outputs the probability that a season ticket member will renew their membership for the next season.

Account data was collected via weekly snapshots throughout the 2017-18 season so that each
account has 53 total observations from July 1 st , 2017 to June 30 th , 2018. With each weekly observation,
the date-dependent variables (those which change from week to week) update to reference either the
most recent 10 games, the past 30, 60, or 90 days, or the past 3, 6, or 12 months. This method of
collection, as opposed to only collecting data as of one date, was chosen so that the model could be run
at any point in time and still have appropriate and accurate predictions. Note that there are 3,353 total
accounts consisting of season ticket members from the 2017-18 season, excluding partners, premium
accounts, and complimentary members. Out of these accounts, 3,012 are renewals from the 2016-17
season. The final dataset consists of 176,755 observations.

The following is a list of each feature gathered in the data collection process. A more detailed
description of the features can be found in the table below. There is a total of 61 features.

 Distance
 IsBusiness
 AvgQtySeat
 AvgSeatPrice
 Upper
 Lower
 CenterSideline
 InnerSideline
 OuterSideline
 Corner
 Baseline
 AvgScanTime
 AvgTixScanned
 PercentLast10
 Resales
 Forwards
 SurveysStarted6/12
 SurveysCompleted6/12
 EmailsRec30/60/90
 EmailsOpen30/60/90
 OpenRate30/60/90
 EmailClicks30/60/90
 ClickRate30/60/90
 OpenClickRate30/60/90
 EmailUnsub6/12
 Rookie
 AddRev6/12
 ArenaRev6/12
 GroupLeader
 Tenure
 Declines3/6
 January, …, December (Month of Obs.)

The first step in building the model was to choose the algorithms to be tested to find the
highest-performing for this dataset. The following is a technical description of each of six model
algorithms tested in the selection process.

Stochastic Gradient Boosting:  
 Produces a prediction model in the form of an ensemble of weak decision trees.
 Repetitively uses the patterns in residuals to strengthen a model with weak predictions until the pattern can no longer be modeled.

Extreme Gradient Boosting: 
 An implementation of the gradient boosting concept.
 Uses a more regularized model formulation to control over-fitting.
 Pushes the limits of the computational resources for boosted tree algorithms.

Random Forest: 
 Constructs multiple decision trees (tree-like graph of decisions and their possible consequences) and
outputs the class that is the mode of the classes of the individual trees.

Support Vector Machines w/ Radial
Basis Function Kernel: 
 Represents the observations as points in space, mapped so that the observations of the 2 classes are divided by a clear gap that is as wide as possible.
 New observations are mapped into that same space and predicted to belong to a class based on which side of the gap they fall.

Boosted Logistic Regression: 
 Uses the log-odds of the probability of an event.
 Simply models probability of output in terms of input.

Linear Discriminant Analysis:  
 Uses Bayes Theorem to make predictions by estimating the probability that a new set of inputs belongs to a class.

The highest performing model was selected based on a variety of summary metrics calculated
by R. The following is a definition of each of five summary metrics used to compare the models, all of
which indicate an excellent model when maximized:

(AU)ROC: The area under the Receiver Operating Characteristic curve, which plots true positive against false positive rate, and shows the ability of the model to correctly classify points.

Sensitivity: When an observation’s true response is ‘No’, it is the probability the model will predict ‘No’.

Specificity: When an observation’s true response is ‘Yes’, it is the probability the model will predict ‘Yes’.

‘No’ Precision: When the model predicts ‘No’, it is the probability that the observation’s true response is ‘No’.

‘Yes’ Precision: When the model predicts ‘Yes’, it is the probability that the observation’s true response is ‘Yes’.

Attempting to train a model on a massive dataset of 176,755 observations leads to exhaustive
training times and expensive memory use. To reduce computational resource use, a random subset of
20,000 observations was taken and used as the training set for the models. This was done in hopes to
speed up processing time without a significant loss of model performance, since 20,000 is still an
adequate sample size.

The following is a comparison of two different Stochastic Gradient Boosting Models, one trained
on the full dataset and one trained on the sample dataset. The 0.0308 reduction in ROC is negligible,
since the model trained on the subset of data ran in 30 minutes as opposed to 3 hours for the model
trained on the full dataset.

Dataset Size: 176,755, ROC: 0.8796 
Dataset Size: 20,000, ROC:  0.8488

Another issue encountered in these initial model building stages was the imbalance of classes in the dataset. Approximately 30% of the dataset consists of accounts who did not renew for the 2018-19 season, while 70% consists of those who did renew. This inconsistency means that when the model is learning, it becomes better at predicting ‘Yes’ responses than ‘No’ responses. As seen in the table above, both Stochastic Gradient Boosting models (regardless of dataset size) could only predict true ‘No’ responses about 50% of the time. To correct this, the random subset of 20,000 observations was specified to consist of 10,000 ‘No’ responses and 10,000 ‘Yes’ responses. This redistributes the model’s predictive strength to both classes. 

The following table is a comparison of two different Stochastic Gradient Boosting Models, one trained on the regular random subset of 20,000 observations and one trained on the random subset of 20,000 observations of which 50% are yes and 50% are no. The model trained on the 50/50 subset has more evenly distributed sensitivity and specificity scores, along with a higher ROC. Moving forward, the six algorithms were trained on their own respective 50/50 subsets of the dataset.

Subset Type: Regular, ROC: 0.8488
Subset Type: 50/50, ROC: 0.8586

The following table shows a comparison between all six of the algorithms and the yielded
summary metrics from their training. In terms of parameter tuning, the optimal values were found using
a random search. The highest performing models are the Stochastic Gradient Boosting, Extreme
Gradient Boosting, and Random Forest. Since the Extreme Gradient Boosting performs better than the
Stochastic, Extreme will be used instead. Moving forward, Random Forest and Extreme Gradient
Boosting will be tested against each other.

Algorithm, ROC:                   
Stochastic Gradient Boosting,  0.8586
Extreme Gradient Boosting,     0.9594
Random Forest,               0.9690
Support Vector Machines,       0.7295
Boosted Logistic Regression,   0.6434
Linear Discriminant Analysis,  0.7186

When predictors in a model are correlated with each other, it can lead to a weaker model. The
precision of the predictions may decrease as more predictors are added, and the contribution of any
one predictor in reducing the total error may vary depending on the inclusion of other predictors. It is
important to analyze the data to find correlated predictors and test if a model performs better on data
without highly correlated predictors.

The following is a list of the predictors with the highest correlation (at least 80%) with another
predictor. Many of the variables are date-dependent and correlated with their counterpart variable of a
different time window (ex: EmailsRec60 correlated with EmailsRec30). Although removing predictors
can be considered a loss of information, any information that these predictors contribute is already
captured in their counterpart predictors.
 Lower
 SurveysCompleted6
 SurveysCompleted12
 EmailsRec60
 EmailsOpen60
 OpenRate60
 EmailClicks60
 OpenClickRate60
 EmailsRec90
 EmailsOpen90
 OpenRate90
 EmailClicks90
 ClickRate90
 ArenaRev6
 Declines6

The following is a comparison among the two contesting models and their counterparts which have
been trained on data without highly correlated predictors. The latter models are stronger, so moving
forward the data lacking highly correlated predictors will be used for training.

Model, ROC:
Random Forest,                         0.9690
Random Forest (No Corr.),              0.9721
Extreme Gradient Boosting,             0.9594
Extreme Gradient Boosting (No Corr.),  0.9668

The two models considered for the final model are the Random Forest and Extreme Gradient
Boosting, both trained on a random subset of 20,000 observations, with 50% yes and 50% no responses,
and no highly correlated predictors.

The following table is a comparison between the summary metrics of the models. The final
model chosen is the Random Forest model because it has a higher ROC and is an overall stronger model.

Model, ROC:
Extreme Gradient Boosting, 0.9668
Random Forest,             0.9721

Real-time season ticket member data is aggregated in an Azure table. All
data in this table is current and references the most recent specified time window. The script which
created this table was written in a similar way to the scripts which created the views previously
described.

The current data table is created with the CurrentData.sql code and then pulled into R via predict.R, where the data is then cleaned and prepared. The random forest model is loaded into the workspace and used to make predictions on the data. The
predictions, an account score of 1-5 calculated by evenly distributed quantiles, the current date, and all
of the data are then outputted back to the SQL server in a table. 
Whenever the prediction script in R is ran on new data, it and its predictions are outputted to this table.
The data is also appended to an archive table, which contains all
data and predictions from each time the model is run on the current data. A task has been scheduled
within RStudio which runs the prediction script every Monday.
