setwd("/home/manish/Techgig/ITC/CodeGladiators-ITCinfotech-DataSet/")

source("/home/manish/Utility Functions/baseRCodes.R")
library(data.table)
library(xgboost)

#Import the data
train<-fread("train_data.csv",stringsAsFactors = FALSE)
test<-fread("test_data.csv",stringsAsFactors = FALSE)

test$Loan_Status<-NA
basedt<-rbind(train,test,use.names=T)

tr.dict<-data.dict(train)

tr.freq<-freq.dist(input = train,varlist = names(train)[2:12],target_cat = "Loan_Status")

fwrite(x = tr.dict$dict,file = "train_dictionary.csv",sep="|",row.names=FALSE)
fwrite(x = tr.freq,file = "train_freq.csv",sep="|",row.names=FALSE)

#Treating some of the variables

basedt[,':='(Gender=ifelse(Gender=='','M','F')
            ,Self_Employed=ifelse(Self_Employed=='','Missing',Self_Employed)
            ,Loan_Amount_Term=ifelse(is.na(Loan_Amount_Term),'Missing',Loan_Amount_Term)
            ,TotalIncome=ApplicantIncome+CoapplicantIncome
            ,CoApplicantFlag=ifelse(CoapplicantIncome==0,'No','Yes')
            ,Credit_History=ifelse(is.na(Credit_History),'Missing',Credit_History)
            ,Inc2Loan=LoanAmount/(ApplicantIncome+CoapplicantIncome)),]

basedt[,':='(B_TotalIncome=cut(TotalIncome
                               ,breaks = c(min(basedt$TotalIncome)
                                           ,quantile(basedt$TotalIncome[1:100]
                                                  ,c(seq(0.1,1,0.1)),na.rm = T)
                                           ,max(basedt$TotalIncome))
                       ,include.lowest = T)
            ,B_LoanAmount=cut(LoanAmount
                              ,breaks = c(min(basedt$LoanAmount)
                                          ,quantile(basedt$LoanAmount[1:100]
                                                    ,c(seq(0.1,1,0.1)),na.rm = T)
                                          ,max(basedt$LoanAmount))
                               ,include.lowest = T)
            ,B_Inc2Loan=cut(Inc2Loan
                            ,breaks = c(min(basedt$Inc2Loan)
                                        ,quantile(basedt$Inc2Loan[1:100]
                                                  ,c(seq(0.1,1,0.1)),na.rm = T)
                                        ,max(basedt$Inc2Loan))
                            ,include.lowest = T))]

basedt[,':='(B_LoanAmount=as.character(B_LoanAmount)
            ,B_TotalIncome=as.character(B_TotalIncome)
            ,B_Inc2Loan=as.character(B_Inc2Loan))]

basedt[,':='(B_LoanAmount=ifelse(is.na(B_LoanAmount),'Missing',B_LoanAmount)
            ,B_Inc2Loan=ifelse(is.na(B_Inc2Loan),'Missing',B_Inc2Loan)),]

View(basedt)

catvar<-c("Gender","Married","Dependents","Education","Self_Employed",'Loan_Amount_Term'
          ,'Credit_History','Property_Area','CoApplicantFlag','B_TotalIncome','B_LoanAmount'
          ,'B_Inc2Loan')
contvar<-c('TotalIncome','ApplicantIncome','CoapplicantIncome')

#Create the model matrix
basedt$random<-runif(n = nrow(basedt))

model.form<-as.formula(paste0("random~",paste(c(catvar,contvar),collapse='+')))

tr.mat=model.matrix(object = model.form,data = basedt)

#For xgboost create the dgcmatrix

xx<-xgb.cv(params =list('eta'=0.001,'max_depth'=4,'min_child_weight'=2
                    ,"lambda"=1,'objective'='binary:logistic') 
       ,data=tr.mat,label = ifelse(train$Loan_Status=='Y',1,0)
       ,nrounds = 1000,nfold =6 )


xx<-xgb.cv(params =list('eta'=0.001,'max_depth'=5,'min_child_weight'=2
                        ,"lambda"=1,'objective'='binary:logistic') 
           ,data=tr.mat[1:100,],label = ifelse(train$Loan_Status=='Y',1,0)
           ,nrounds = 2000,nfold =4 )

#Get the model

xgb.model<-xgboost(data=tr.mat[1:100,],label = ifelse(basedt$Loan_Status[1:100]=='Y',1,0)
                   ,nrounds = 2000
                  ,params =list('eta'=0.001,'max_depth'=5,'min_child_weight'=2
                                ,"lambda"=1,'objective'='binary:logistic') )

xgb.pred<-data.frame('actual'=ifelse(train$Loan_Status=='Y',1,0)
                     ,'PredProb'=predict(xgb.model,newdata = tr.mat))

#Do the rank ordering

setDT(xgb.pred)

xgb.pred[,prob.quant:=cut(x = PredProb,breaks = quantile(PredProb,seq(0,1,0.1))
                          ,include.lowest = TRUE)]

table(xgb.pred$prob.quant,xgb.pred$actual)

#Using h20
library(h2o)

h2o.init(enable_assertions = FALSE)
tr.h2o<-as.h2o(cbind(tr.mat,"Loan_Status"=basedt$Loan_Status))

tr.dl <- h2o.deeplearning( y ='Loan_Status',training_frame = tr.h2o[1:100,]
                           ,nfolds = 5,hidden = 7,seed = 1234
                           ,l1=0,variable_importances = TRUE
                           ,distribution ="bernoulli"
                           ,l2 = 1,activation = 'Tanh',stopping_rounds = 20)

dl.pred<-as.data.frame(predict(tr.dl,tr.h2o))

dl.pred<-data.frame('actual'=ifelse(train$Loan_Status=='Y',1,0)
                     ,'PredProb'=dl.pred$Y)

#Do the rank ordering

setDT(dl.pred)

dl.pred[,prob.quant:=cut(x = PredProb,breaks = quantile(PredProb,seq(0,1,0.1))
                          ,include.lowest = TRUE)]

table(dl.pred$prob.quant,dl.pred$actual)

#Lets do a basic stacking

pred.1=data.frame("actual"=xgb.pred$actual,
                  'xgb.pred'=xgb.pred$PredProb
                  ,'dl.pred'=dl.pred$PredProb)

setDT(pred.1)

#Lets combine the results
h2o.pr<-as.data.frame(predict(tr.dl,newdata = tr.h2o))

Pred.Combine<-data.frame("actual"=basedt$Loan_Status,
                         'xgb.pred'=predict(xgb.model,newdata = tr.mat)
                         ,'dl.pred'=h2o.pr$Y)
setDT(Pred.Combine)
#Rebuild the xgboost model with these two predictions

xx.1<-xgboost(params =list('eta'=0.001,'max_depth'=4,'min_child_weight'=2
                        ,"lambda"=1,'objective'='binary:logistic') 
           ,data=as.matrix(Pred.Combine[1:100,c('xgb.pred','dl.pred'),with=FALSE])
           ,label = ifelse(basedt$Loan_Status[1:100]=='Y',1,0)
           ,nrounds = 2000
          # ,nfold =5 
           )


#Predicton for the test sample
testpred<-data.table("Application_ID"=test$Application_ID
                     ,"Loan_Status"=predict(xx.1
                                            ,newdata = as.matrix(Pred.Combine[101:614
                                                                              ,c('xgb.pred','dl.pred')
                                                                              ,with=FALSE])))

testpred[,Loan_Status:=ifelse(Loan_Status>=0.3,"Y","N")]

write.csv(testpred,"testpred.csv",row.names=FALSE)

st<-data.frame('actual'=ifelse(train$Loan_Status=='Y',1,0)
                     ,'PredProb'=predict(xx.1,newdata = as.matrix(Pred.Combine[1:100,c('xgb.pred','dl.pred')
                                                                        ,with=FALSE])))

#Do the rank ordering

setDT(st)

st[,prob.quant:=cut(x = PredProb,breaks = unique(quantile(PredProb,seq(0,1,0.15)))
                          ,include.lowest = TRUE)]

table(st$PredProb,st$actual)



