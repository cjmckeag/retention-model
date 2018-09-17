library(RODBC) # server connection
library(base) # lapply
library(Hmisc) # impute
######################################################################################################

# connect to SQL server
sqlServer <- "ssbkingsdb01.database.secure.windows.net"  #Enter Azure SQL Server
sqlDatabase <- "kingsdb"                #Enter Database Name
sqlUser <- "kings_cmckeag"             #Enter the SQL User ID
sqlPassword <- "P9$T&8fx6^ZN#Jn"        #Enter the User Password
sqlDriver <- "SQL Server"        #Leave this Drive Entry
connectionStringSQL <- paste0(
  "Driver=", sqlDriver, 
  ";Server=", sqlServer, 
  ";Database=", sqlDatabase, 
  ";Uid=", sqlUser, 
  ";Pwd=", sqlPassword,
  ";Encrypt=yes",
  ";Port=1433")
conn <- odbcDriverConnect(connectionStringSQL)

# bring in data from kings.vw_retention_data
data <- sqlQuery(conn, 'SELECT * FROM [kings].[vw_retention_data]')

# remove accountid; datavar should have 46 variables
datavar<- data[-c(1)]

# impute missing scan time values with median
datavar$AvgScanTime<-impute(datavar$AvgScanTime,median)

# set working directory to Box
setwd("D:\\Users\\cmckeag\\Box\\Analytics\\Retention")

# load random forest model
load("2018 Retention Model.RData")

# make predictions
prediction <- predict(rf, datavar,type='prob')
colnames(prediction)[2]<-'RenewalProb'
Date<-Sys.Date()
quantiles<-data.frame(quantile(prediction$RenewalProb,probs=seq(0,1,0.2)))
prediction<-within(prediction,prediction$Score<-ifelse(RenewalProb>=quantiles[,1][1] & RenewalProb<=quantiles[,1][2],1,
                                                                        ifelse(RenewalProb>quantiles[,1][2] & RenewalProb<=quantiles[,1][3],2,
                                                                               ifelse(RenewalProb>quantiles[,1][3] & RenewalProb<=quantiles[,1][4],3,
                                                                                      ifelse(RenewalProb>quantiles[,1][4] & RenewalProb<=quantiles[,1][5],4,
                                                                                             ifelse(RenewalProb>quantiles[,1][5] & RenewalProb<=quantiles[,1][6],5,NA))))))
preds<-data.frame(data[1],prediction[2],prediction$prediction$Score,Date,datavar)
colnames(preds)[3]<-'Score'

# append data to archive table with all previous runs called kings.STMRenewalPredictions_Archive
sqlSave(conn,preds,tablename='kings.STMRenewalPredictions_Archive',append=TRUE,rownames=FALSE, safer=FALSE,
        varTypes=c(archticsAccountId='int',RenewalProb='float',Score='int',Date='date',Distance='float',IsBusiness='int',AvgQtySeat='int',
                   AvgSeatPrice='float',Upper='int',CenterSideline='int',InnerSideline='int',OuterSideline='int',Corner='int',Baseline='int',AvgScanTime='float',AvgTixScanned='float',
                   PercentLast10='float',Resales='int',Forwards='int',SurveysStarted6='int',SurveysStarted12='int',EmailsRec30='int',EmailsOpen30='int',OpenRate30='float',EmailClicks30='int',
                   ClickRate30='float',OpenClickRate30='float',ClickRate60='float',OpenClickRate90='float',EmailUnsub6='int',EmailUnsub12='int',Rookie='int',AddRev6='float',AddRev12='float',
                   ArenaRev12='float',GroupLeader='int',Tenure='int',Declines3='int',January='int',February='int',March='int',April='int',May='int',June='int',July='int',September='int',
                   October='int',November='int',December='int'))

# write dataset with accountid, renewal probability, account score, current date, and account data to SQL table with CURRENT PREDICTIONS ONLY called kings.STMRenewalPredictions
sqlSave(conn,preds,tablename='kings.STMRenewalPredictions',append=FALSE,rownames=FALSE, safer=FALSE,
        varTypes=c(archticsAccountId='int',RenewalProb='float',Score='int',Date='date',Distance='float',IsBusiness='int',AvgQtySeat='int',
                   AvgSeatPrice='float',Upper='int',CenterSideline='int',InnerSideline='int',OuterSideline='int',Corner='int',Baseline='int',AvgScanTime='float',AvgTixScanned='float',
                   PercentLast10='float',Resales='int',Forwards='int',SurveysStarted6='int',SurveysStarted12='int',EmailsRec30='int',EmailsOpen30='int',OpenRate30='float',EmailClicks30='int',
                   ClickRate30='float',OpenClickRate30='float',ClickRate60='float',OpenClickRate90='float',EmailUnsub6='int',EmailUnsub12='int',Rookie='int',AddRev6='float',AddRev12='float',
                   ArenaRev12='float',GroupLeader='int',Tenure='int',Declines3='int',January='int',February='int',March='int',April='int',May='int',June='int',July='int',September='int',
                   October='int',November='int',December='int'))   


#library(taskscheduleR)
#taskscheduler_create(taskname = "Predict", rscript = "D:\\Users\\cmckeag\\Box\\Analytics\\Retention\\predict.R", schedule="WEEKLY", startdate = format(as.Date("2018-09-17"), "%m/%d/%Y"),starttime = "00:01")
