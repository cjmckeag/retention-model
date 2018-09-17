library(caret) # train function
library(parallel) # parallel processing
library(doParallel) # parallel processing
library(xgboost) # xgbTree
library(plyr) # xgbTree
library (randomForest) # random forest
library(kernlab) # svmLinear
library(caTools) # LogitBoost
library(MASS) # lda
library(caretEnsemble) # stacking
##################################################################################################

# parallel processing: process models in parallel for faster response time
# convention to leave 1 core for OS
cluster <- makeCluster(detectCores() - 1)
# register the parallel backend
registerDoParallel(cluster)

##################################################################################################

# set working directory
setwd("~/retention")

# Data Cleaning: remove irrelevant variables (accountid and mydate), convert distance and tenure to numeric, convert renewed to factor, recreate dataset
#                with newly converted variables, change names of factor levels to yes (renewed) and no (did not renew)

# load data
dataset<-read.csv(file="retentiondata.csv")
# remove accountid and mydate columns
dataset<-dataset[-c(1,2)]
attach(dataset)
# convert Distance and Tenure to numeric (brought in as factors for some reason)
Distance=as.numeric(Distance)
Tenure=as.numeric(Tenure)
# convert Renewed to factor in order to use classification rather than regression
Renewed=as.factor(renewed)
# recreate dataset using newly converted variables
dataset<-data.frame(Renewed,Distance,IsBusiness,AvgQtySeat,AvgSeatPrice,Upper,Lower,CenterSideline,InnerSideline,OuterSideline,Corner,Baseline,AvgScanTime,AvgTixScanned,PercentLast10,Resales,Forwards,SurveysStarted6,SurveysCompleted6,SurveysStarted12,SurveysCompleted12,EmailsRec30,EmailsOpen30,OpenRate30,EmailClicks30,ClickRate30,OpenClickRate30,EmailsRec60,EmailsOpen60,OpenRate60,EmailClicks60,ClickRate60,OpenClickRate60,EmailsRec90,EmailsOpen90,OpenRate90,EmailClicks90,ClickRate90,OpenClickRate90,EmailUnsub6,EmailUnsub12,Rookie,AddRev6,AddRev12,ArenaRev6,ArenaRev12,GroupLeader,Tenure,Declines3,Declines6,January,February,March,April,May,June,July,August,September,October,November,December)
# create dataset with only predictors
predictors<-dataset[-c(1)]
# change names of levels because 0 and 1 can cause errors
levels(Renewed)[levels(Renewed)==0]<-'no'
levels(Renewed)[levels(Renewed)==1]<-'yes'

##################################################################################################

# Metric Definitions
# Accuracy: the number of correct predictions made by the model over all kinds predictions made.
#           should NEVER be used as a measure when the target variable classes in the data are a majority of one class
# Receiver Operating Characteristic Plot (ROC):  illustrates the diagnostic ability of a binary classifier system 
#                                                as its discrimination threshold is varied.
#                                                plots the true positive rate against the false positive rate (sensitivity vs fall-out)
# Specificity (Recall): given that a result is truly an event, what is the probability that the model will predict an event results?
# Sensitivity: given that a result is truly not an event, what is the probability that the model will predict a negative results?
# no/yes Precision: when the model predicts no/yes, how often is it correct?

##################################################################################################

# Model Training

# Train model on full dataset

#Stochastic Gradient Boosting Method on FULL DATA
# define computational nuances of train function: 10-fold CrossValidation, allow parallel processing, compute class probabilities
fitControl <- trainControl(method = "cv",
                           number = 10,
                           allowParallel = TRUE,classProbs=TRUE,summaryFunction = twoClassSummary)
# set seed immediately prior to model training
set.seed(1)
gbmGrid<-expand.grid(interaction.depth = c(3,5,7,9),n.trees = c(150,175,200),shrinkage = c(0.1,0.05),n.minobsinnode = 10)
set.seed(1)
gbm <- train(x=predictors,y=Renewed, method="gbm",trControl = fitControl, tuneGrid=gbmGrid)
# optimal model tune: n.trees=200, interaction.depth=9, shrinkage=0.1, n.minobsinnode=10
gbm$resample
confusionMatrix(gbm)
# Accuracy: 0.8081
# Sensitivity: 0.4959
# Specificity: 0.9494
# 'no' Precision: 0.8148
# 'yes' Precision: 0.8064
# ROC: 0.8796

##################################################################################################

# Model on full dataset is expensive and time-consuming due to large dataset; attempt to train model on random subset of dataset and achieve similar metrics

# Stochastic Gradient Boosting -> Random Subset of NONPROCESSED Data
gbmsample <- dataset[sample(1:nrow(dataset), 20000,replace=FALSE),]
gbmsamplepredictors <- gbmsample[-c(1)]
gbmsampleRenewed<- gbmsample$Renewed
levels(gbmsampleRenewed)[levels(gbmsampleRenewed)==0]<-'no'
levels(gbmsampleRenewed)[levels(gbmsampleRenewed)==1]<-'yes'
# train GBM model on random subset
gbmControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary)
gbmGrid<-expand.grid(interaction.depth = c(3,5,7,9),n.trees = c(150,175,200),shrinkage = 0.1,n.minobsinnode = 10)
set.seed(1)
gbm<-train(x=gbmsamplepredictors,y=gbmsampleRenewed,method='gbm',trControl=gbmControl,tuneGrid=gbmGrid)
# optimal tuning parameters: n.trees = 200, interaction.depth = 9, shrinkage = 0.1 and n.minobsinnode = 10.
# Accuracy: 0.7951
# Sensitivity: 0.4761
# Specificity: 0.9361
# 'no' Precision: 0.7684
# 'yes' Precision: 0.8012
# ROC: 0.8488

# 170k observations vs 20k observations: ROC=0.8796 vs ROC=0.8488
# Trade-off of ROC and training time is acceptable, proceed with using random subset of 20,000 observations

# Stochastic Gradient Boosting -> Random Subset of 50/50 NONPROCESSED Data
gbm5050sample<-rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
gbm5050samplepredictors <- gbm5050sample[-c(1)]
gbm5050sampleRenewed<- gbm5050sample$Renewed
levels(gbm5050sampleRenewed)[levels(gbm5050sampleRenewed)==0]<-'no'
levels(gbm5050sampleRenewed)[levels(gbm5050sampleRenewed)==1]<-'yes'
# train GBM model on random subset
gbmControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary)
gbmGrid<-expand.grid(interaction.depth = c(3,5,7,9),n.trees = c(150,175,200),shrinkage = 0.1,n.minobsinnode = 10)
set.seed(1)
gbm<-train(x=gbm5050samplepredictors,y=gbm5050sampleRenewed,method='gbm',trControl=gbmControl,tuneGrid=gbmGrid)
# optimal tuning parameters: n.trees = 200, interaction.depth = 9, shrinkage = 0.1 and n.minobsinnode = 10.
# Accuracy: 0.772
# Sensitivity: 0.7702
# Specificity: 0.7739
# 'no' Precision: 0.7731
# 'yes' Precision: 0.7709
# ROC: 0.8586

# The model trained on the 50/50 yes/no distributed data is more balanced and stronger... use 50/50 data for all models now

##################################################################################################

# Xtreme Gradient Boosting -> Random Subset of 50/50 NONPROCESSED Data
xgbsample <- rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
xgbsamplepredictors <- xgbsample[-c(1)]
xgbsampleRenewed<- xgbsample$Renewed
levels(xgbsampleRenewed)[levels(xgbsampleRenewed)==0]<-'no'
levels(xgbsampleRenewed)[levels(xgbsampleRenewed)==1]<-'yes'
xgbControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
xgb<-train(x=xgbsamplepredictors,y=xgbsampleRenewed,method='xgbTree',trControl=xgbControl)
# optimal tuning parameters: nrounds = 573, max_depth = 9, eta = 0.3778393, gamma = 1.765568, colsample_bytree = 0.6079366, min_child_weight = 20 and subsample = 0.9510289
# Accuracy: 0.8966
# Sensitivity: 0.9103
# Specificity: 0.8829
# 'no' Precision: 0.8852
# 'yes' Precision: 0.9074
# ROC: 0.9594

# Random Forest -> Random Subset of 50/50 NONPROCESSED Data
rfsample <- rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
rfsamplepredictors <- rfsample[-c(1)]
rfsampleRenewed<- rfsample$Renewed
levels(rfsampleRenewed)[levels(rfsampleRenewed)==0]<-'no'
levels(rfsampleRenewed)[levels(rfsampleRenewed)==1]<-'yes'
rfControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
rf<-train(x=rfsamplepredictors,y=rfsampleRenewed,method='rf',trControl=rfControl)
# optimal tuning parameters: mtry=50
# Accuracy: 0.9111
# Sensitivity: 0.9238
# Specificity: 0.8985
# 'no' Precision: 0.9006
# 'yes' Precision: 0.9220
# ROC: 0.9690

# Support Vector Machines -> Random Subset of 50/50 NONPROCESSED Data
svmsample <- rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
svmsamplepredictors <- svmsample[-c(1)]
svmsampleRenewed<- svmsample$Renewed
levels(svmsampleRenewed)[levels(svmsampleRenewed)==0]<-'no'
levels(svmsampleRenewed)[levels(svmsampleRenewed)==1]<-'yes'
svmControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
svm<-train(x=svmsamplepredictors,y=svmsampleRenewed,method='svmRadial',trControl=svmControl)
# optimal tuning parameters: sigma = 0.00372198 and C = 7.465433
# Accuracy: 0.7178
# Sensitivity: 0.6421
# Specificity: 0.6959
# 'no' Precision: 0.7243
# 'yes' Precision: 0.7121
# ROC: 0.7295
# This support vector machines model ^ is inadequate, eliminate.

# Boosted Logistic Regression -> Random Subset of 50/50 NONPROCESSED Data
logitsample <- rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
logitsamplepredictors <- logitsample[-c(1)]
logitsampleRenewed<- logitsample$Renewed
levels(logitsampleRenewed)[levels(logitsampleRenewed)==0]<-'no'
levels(logitsampleRenewed)[levels(logitsampleRenewed)==1]<-'yes'
logitControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
logit<-train(x=logitsamplepredictors,y=logitsampleRenewed,method='LogitBoost',trControl=logitControl)
# optimal tuning parameters: nIter=31
# Accuracy: 0.6219
# Sensitivity: 0.6472
# Specificity: 0.5966
# 'no' Precision: 0.6160
# 'yes' Precision: 0.6287
# ROC: 0.6434
# This logistic regression model ^ is inadequate, eliminate.

# Linear Discriminant Analysis -> Random Subset of 50/50 NONPROCESSED Data
ldasample <- rbind(dataset[ sample( which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[ sample( which(dataset$Renewed==0), 10000,replace=FALSE),])
ldasamplepredictors <- ldasample[-c(1)]
ldasampleRenewed<- ldasample$Renewed
levels(ldasampleRenewed)[levels(ldasampleRenewed)==0]<-'no'
levels(ldasampleRenewed)[levels(ldasampleRenewed)==1]<-'yes'
ldaControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
lda<-train(x=ldasamplepredictors,y=ldasampleRenewed,method='lda',trControl=ldaControl)
# optimal tuning parameters: N/A
# Accuracy: 0.6582
# Sensitivity: 0.6322
# Specificity: 0.6842
# 'no' Precision: 0.6667
# 'yes' Precision: 0.6502
# ROC: 0.7186
# This linear discriminant analysis model ^ is inadequate, eliminate.


##################################################################################################

# Train models on data without correlated predictors

# finding highly correlated predictors
descrCor <-  cor(predictors)
highCorr <- sum(abs(descrCor[upper.tri(descrCor)]) > .999)
summary(descrCor[upper.tri(descrCor)])
highlyCorDescr <- findCorrelation(descrCor, cutoff = .80)
# remove highly correlated predictors
nocorrpredictors <- predictors[,-highlyCorDescr]
nocorrdataset <- data.frame(Renewed,nocorrpredictors)
levels(nocorrdataset$Renewed)[levels(nocorrdataset$Renewed)=='no']<-0
levels(nocorrdataset$Renewed)[levels(nocorrdataset$Renewed)=='yes']<-1

# Xtreme Gradient Boosting -> Random Subset of 50/50 NONPROCESSED No-Correlation Data
xgbnocorrsample <- rbind(nocorrdataset[sample(which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[sample(which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
xgbnocorrsamplepredictors <- xgbnocorrsample[-c(1)]
xgbnocorrsampleRenewed<- xgbnocorrsample$Renewed
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==0]<-'no'
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==1]<-'yes'
xgbControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
xgbnocorr<-train(x=xgbnocorrsamplepredictors,y=xgbnocorrsampleRenewed,method='xgbTree',trControl=xgbControl)
# optimal tuning parameters: nrounds = 573, max_depth = 9, eta = 0.3778393, gamma = 1.765568, colsample_bytree = 0.6079366, min_child_weight = 20 and subsample = 0.9510289
# Accuracy: 0.9101
# Sensitivity: 0.9247
# Specificity: 0.8956
# 'no' Precision: 0.8988
# 'yes' Precision: 0.9218
# ROC: 0.9668
# Overall better results than model trained on data with correlated variables: ROC=0.9668 vs ROC=0.9594

# Random Forest -> Random Subset of 50/50 NONPROCESSED No-Correlation Data
rfnocorrsample <- rbind(nocorrdataset[ sample( which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[ sample( which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
rfnocorrsamplepredictors <- rfnocorrsample[-c(1)]
rfnocorrsampleRenewed<- rfnocorrsample$Renewed
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==0]<-'no'
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==1]<-'yes'
rfControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
rfnocorr<-train(x=rfnocorrsamplepredictors,y=rfnocorrsampleRenewed,method='rf',trControl=rfControl)
# optimal tuning parameters: mtry=42
# Accuracy: 0.9169
# Sensitivity: 0.9321
# Specificity: 0.9016
# 'no' Precision: 0.9049
# 'yes' Precision: 0.9299
# ROC: 0.9721
# Overall better results than model trained on data with correlated variables: ROC=0.9721 vs ROC=0.9690


##################################################################################################

# Train models on preprocessed data, specific to algorithm

# Xtreme Gradient Boosting -> Random Subset of 50/50 PCA No-Correlation Data
xgbnocorrsample <- rbind(nocorrdataset[sample(which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[sample(which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
xgbnocorrsamplepredictors <- xgbnocorrsample[-c(1)]
xgbnocorrsampleRenewed<- xgbnocorrsample$Renewed
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==0]<-'no'
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==1]<-'yes'
xgbControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
xgbppnocorr<-train(x=xgbnocorrsamplepredictors,y=xgbnocorrsampleRenewed,method='xgbTree',trControl=xgbControl,preprocess='pca')
# optimal tuning parameters: nrounds = 573, max_depth = 9, eta = 0.3778393, gamma = 1.765568, colsample_bytree = 0.6079366, min_child_weight = 20 and subsample = 0.9510289
# Accuracy: 0.9078
# Sensitivity: 0.9234
# Specificity: 0.8922
# 'no' Precision: 0.8953
# 'yes' Precision: 0.9215
# ROC: 0.9659
# The model is slightly worse than the model built on 50/50 nonprocessed no-correlation data: ROC=0.9659 vs ROC=0.9668

# Xtreme Gradient Boosting -> Random Subset of 50/50 PCA Data (with correlation)
xgbppsample <- rbind(dataset[sample(which(dataset$Renewed==1), 10000,replace=FALSE),],dataset[sample(which(dataset$Renewed==0), 10000,replace=FALSE),])
xgbppsamplepredictors <- xgbppsample[-c(1)]
xgbppsampleRenewed<- xgbppsample$Renewed
levels(xgbppsampleRenewed)[levels(xgbppsampleRenewed)==0]<-'no'
levels(xgbppsampleRenewed)[levels(xgbppsampleRenewed)==1]<-'yes'
xgbControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
xgbpp<-train(x=xgbppsamplepredictors,y=xgbppsampleRenewed,method='xgbTree',trControl=xgbControl,preprocess='pca')
# optimal tuning parameters: nrounds = 573, max_depth = 9, eta = 0.3778393, gamma = 1.765568, colsample_bytree = 0.6079366, min_child_weight = 20 and subsample = 0.9510289.
# Accuracy: 0.9008
# Sensitivity: 0.9159
# Specificity: 0.8857
# 'no' Precision: 0.8893
# 'yes' Precision: 0.9134
# ROC: 0.9616
# The model is worse than the model built on 50/50 processed no-correlation data: ROC=0.9616 vs ROC=0.9659

# Random Forest does not need any preprocessing

##################################################################################################

# FINAL INDIVIDUAL MODELS

# Xtreme Gradient Boosting -> Random Subset of 50/50 NONPROCESSED No-Correlation Data
xgbnocorrsample <- rbind(nocorrdataset[sample(which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[sample(which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
xgbnocorrsamplepredictors <- xgbnocorrsample[-c(1)]
xgbnocorrsampleRenewed<- xgbnocorrsample$Renewed
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==0]<-'no'
levels(xgbnocorrsampleRenewed)[levels(xgbnocorrsampleRenewed)==1]<-'yes'
xgbControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary,search='random')
set.seed(1)
xgbnocorr<-train(x=xgbnocorrsamplepredictors,y=xgbnocorrsampleRenewed,method='xgbTree',trControl=xgbControl)
# optimal tuning parameters: nrounds = 573, max_depth = 9, eta = 0.3778393, gamma = 1.765568, colsample_bytree = 0.6079366, min_child_weight = 20 and subsample = 0.9510289
# Accuracy: 0.9101
# Sensitivity: 0.9247
# Specificity: 0.8956
# 'no' Precision: 0.8988
# 'yes' Precision: 0.9218
# ROC: 0.9668

# Random Forest -> Random Subset of 50/50 NONPROCESSED No-Correlation Data
rfnocorrsample <- rbind(nocorrdataset[ sample( which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[ sample( which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
rfnocorrsamplepredictors <- rfnocorrsample[-c(1)]
rfnocorrsampleRenewed<- rfnocorrsample$Renewed
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==0]<-'no'
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==1]<-'yes'
rfControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary)
rfGrid=expand.grid(mtry=c(42))
set.seed(1)
rf<-train(x=rfnocorrsamplepredictors,y=rfnocorrsampleRenewed,method='rf',trControl=rfControl,tuneGrid=rfGrid)
# optimal tuning parameters: mtry=42
# Accuracy: 0.9169
# Sensitivity: 0.9321
# Specificity: 0.9016
# 'no' Precision: 0.9049
# 'yes' Precision: 0.9299
# ROC: 0.9721

##################################################################################################

# FINAL MODEL

# Random Forest -> Random Subset of 50/50 NONPROCESSED No-Correlation Data
rfnocorrsample <- rbind(nocorrdataset[ sample( which(nocorrdataset$Renewed==1), 10000,replace=FALSE),],nocorrdataset[ sample( which(nocorrdataset$Renewed==0), 10000,replace=FALSE),])
rfnocorrsamplepredictors <- rfnocorrsample[-c(1)]
rfnocorrsampleRenewed<- rfnocorrsample$Renewed
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==0]<-'no'
levels(rfnocorrsampleRenewed)[levels(rfnocorrsampleRenewed)==1]<-'yes'
rfControl=trainControl(method='repeatedcv',number=10,repeats=3,allowParallel=TRUE,classProbs=TRUE,summaryFunction=twoClassSummary)
rfGrid=expand.grid(mtry=c(42))
set.seed(1)
rf<-train(x=rfnocorrsamplepredictors,y=rfnocorrsampleRenewed,method='rf',trControl=rfControl,tuneGrid=rfGrid)
# optimal tuning parameters: mtry=42
# Accuracy: 0.9169
# Sensitivity: 0.9321
# Specificity: 0.9016
# 'no' Precision: 0.9049
# 'yes' Precision: 0.9299
# ROC: 0.9721

##################################################################################################

# de-register parallel processing cluster to return to single threaded processing
stopCluster(cluster)
registerDoSEQ()

##################################################################################################

save(rf, file = "2018 Retention Model.RData")
