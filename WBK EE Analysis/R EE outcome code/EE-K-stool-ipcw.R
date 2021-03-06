

#---------------------------------------
# EE-BD-stool.R
#
# andrew mertens (amertens@berkeley.edu)
#
# The stool-based biomarker outcomes for 
# EED Kenya sub-study - ipcw analysis
#---------------------------------------


rm(list=ls())
library(tidyverse)
library(foreign)
library(washb)
library(lubridate)


#Load in blinded treatment information
setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew")
#tr <- read.csv("raw CSV/washk_blindTR.csv")
tr <- read.csv("raw CSV/washk_TR.csv")
tr$tr <- factor(tr$tr, levels = c("Control",  "WSH", "Nutrition", "Nutrition + WSH"))
head(tr)

#Child dates of birth
dob <- readRDS("WBK-EE-childDOB.rds")
#use main trial DOB
dob <- dob %>% subset(., select = -c(sex,DOB))

#Stool outcomes
outcomes<-read.csv("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew/raw CSV/washk_ee_stool.csv")
head(outcomes)



#Stool collection dates and staffid
load("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew/washk_ee_stool_survey.Rdata")


#Rename outcomes:
outcomes <- outcomes %>%
  rename(aat1=t1_aat,
         aat2=t2_aat,
         aat3=t3_aat,
         mpo1=t1_mpo,
         mpo2=t2_mpo,
         mpo3=t3_mpo,
         neo1=t1_neo,
         neo2=t2_neo,
         neo3=t3_neo)

#Baseline covariates from main trial
enrol<-read.dta("C:/Users/andre/Dropbox/washb_Kenya_primary_outcomes_Andrew/Data-selected/clean/washb-kenya-enrol.dta")
head(enrol)

d <- left_join(outcomes, dob, by="childid")

d <- left_join(d, stsurv, by="childid")

dim(d)
d <- left_join(enrol, d, by="childid")
dim(d)
#Subset to EED arms
d<-subset(d, tr=="Control" | tr=="WSH" | tr=="Nutrition" | tr=="Nutrition + WSH")
dim(d)

#----------------------------------------
# Drop childids with data problems
#----------------------------------------


# Load in id issues from Charles
idprobs <- read.csv("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Untouched/Missing DOB or sex CA_AL.csv")
idprobs
idprobs <- idprobs %>% 
           rename(sex2 = sex, DOB2 = DOB) %>% 
           subset(., select = c(childid, sex2, DOB2, Action)) %>% 
           mutate(sex2 = ifelse(sex2 == 1, 1, 0))


#Merge into main data.frame
d <- left_join(d, idprobs, by = c("childid")) 

#Drop children with data issues
d <- d %>% filter(Action=="keep" | is.na(Action))

#Fill in sex and dob for children missing it in stool dataset
d$sex[is.na(d$sex)] <- d$sex2[is.na(d$sex)] 
d$DOB[is.na(d$DOB)] <- d$DOB2[is.na(d$DOB)]

d <- d %>% subset(., select = -c(sex2, DOB2, Action))

#Drop rows with no outcomes
d <- d %>% filter(!is.na(aat1) | !is.na(aat2) | !is.na(aat3) | 
                    !is.na(mpo1) | !is.na(mpo2) | !is.na(mpo3) | 
                    !is.na(neo1) | !is.na(neo2) | !is.na(neo3))

#Calculate child age and month of the year at each measurement
d <- d %>% 
        mutate(aged1= stool_bl_date-DOB,
               aged2= stool_ml_date-DOB,
               aged3= stool_el_date-DOB,
               agem1= as.numeric(aged1/30.25), 
               agem2= as.numeric(aged2/30.25), 
               agem3= as.numeric(aged3/30.25),
               month1= month(d$stool_bl_date),
               month2= month(d$stool_ml_date),
               month3= month(d$stool_el_date))
               


############################
#Set outcomes:
############################

#dataframe of stool biomarkers:
Y<-d %>% select(neo1,mpo1,aat1,neo2,mpo2,aat2,neo3,mpo3,aat3)

#Set contrasts:
contrasts <- list(c("Control","WSH"), c("Control","Nutrition"), c("Control","Nutrition + WSH"), c("WSH","Nutrition + WSH"), c("Nutrition","Nutrition + WSH"))



#------------------
# Rename covariates
#------------------

d <- d %>%
   rename(elec = electricity,
          hfiacat = HHS,
          asset_radio = radio, 
          asset_tv = television, 
          asset_mobile = mobile, 
          asset_clock = clock, 
          asset_bike = bicycle, 
          asset_moto = motorcycle, 
          asset_stove = stove,  
          n_cows = cow, 
          n_goats = goat,
          n_chickens = chicken, 
          n_dogs = dog, 
          watmin = dminwat)



#------------------
# Clean covariates
#------------------

d$asset_tv <- factor(d$asset_tv)
d$elec <- factor(d$elec)
d$momedu <- factor(d$momedu)

d$asset_tv <-relevel(d$asset_tv, ref = "0")
d$elec <-relevel(d$elec, ref = "0")
d$momedu <-relevel(d$momedu, ref = "Incomplete Primary")

d$month1 <- factor(d$month1)
d$month2 <- factor(d$month2)
d$month3 <- factor(d$month3)
d$staffid1 <- factor(d$staffid1)
d$staffid2 <- factor(d$staffid2)
d$staffid3 <- factor(d$staffid3)


#Make vectors of adjustment variable names
Wvars<-c("sex", "birthord",  "momage", "momedu",  "Ncomp", "Nlt18", "elec","roof",
         "momheight",
         "asset_radio", "asset_tv", "asset_mobile", "asset_clock", "asset_bike", "asset_moto", "asset_stove",  
         "n_cows", "n_goats","n_chickens", "n_dogs", "watmin", "hfiacat")

#Add in time varying covariates:
Wvars1<-c("aged1", "month1", "staffid1") 
Wvars2<-c("aged2", "month2", "staffid2") 
Wvars3<-c("aged3", "month3", "staffid3") 



#subset time-constant W adjustment set
W<- subset(d, select=Wvars)


#Add in time-varying covariates
W1<- cbind(W, subset(d, select=Wvars1))
W2<- cbind(W, subset(d, select=Wvars2))
W3<- cbind(W, subset(d, select=Wvars3))


#Set time-varying covariates as factors
W1$month1<-as.factor(W1$month1)
W2$month2<-as.factor(W2$month2)
W3$month3<-as.factor(W3$month3)
W1$staffid1<-factor(W1$staffid1)
W2$staffid2<-factor(W2$staffid2)
W3$staffid3<-factor(W3$staffid3)



#Tabulate missingness
for(i in 1:ncol(W)){
  print(colnames(W)[i])
  print(table(is.na(W[,i])))
}


#Print means for continious, Ns for factors
for(i in 1:ncol(W)){
  print(colnames(W)[i])
  if(class(W[,i])=="factor"){
    print(table(W[,i]))
  }else{print(mean(W[,i], na.rm=T))}
}



for(i in 1:ncol(W3)){
  print(colnames(W3)[i])
  if(class(W3[,i])=="factor"){
    print(table(W3[,i]))
  }else{print(mean(W3[,i], na.rm=T))}
}




##############################################
#Run GLMs for the adjusted parameter estimates
##############################################



#Set contrasts:
contrasts <- list(c("Control","WSH"), c("Control","Nutrition"), c("Control","Nutrition + WSH"), c("WSH","Nutrition + WSH"), c("Nutrition","Nutrition + WSH"))



#Create indicators for missingness
d$aat1.miss<-ifelse(is.na(d$aat1),0,1)
d$aat2.miss<-ifelse(is.na(d$aat2),0,1)
d$aat3.miss<-ifelse(is.na(d$aat3),0,1)

d$mpo1.miss<-ifelse(is.na(d$mpo1),0,1)
d$mpo2.miss<-ifelse(is.na(d$mpo2),0,1)
d$mpo3.miss<-ifelse(is.na(d$mpo3),0,1)

d$neo1.miss<-ifelse(is.na(d$neo1),0,1)
d$neo2.miss<-ifelse(is.na(d$neo2),0,1)
d$neo3.miss<-ifelse(is.na(d$neo3),0,1)


table(d$aat1.miss)
table(d$aat2.miss)
table(d$aat3.miss)

table(d$mpo1.miss)
table(d$mpo2.miss)
table(d$mpo3.miss)

table(d$neo1.miss)
table(d$neo2.miss)
table(d$neo3.miss)

table(d$aat1.miss)
table(d$aat2.miss)
table(d$aat3.miss)



# set missing outcomes to an arbitrary, non-missing value. In this case use 9
d$aat1Delta <- d$aat1
d$aat1Delta[d$aat1.miss==0] <- exp(9)

d$aat2Delta <- d$aat2
d$aat2Delta[d$aat2.miss==0] <- exp(9)

d$aat3Delta <- d$aat3
d$aat3Delta[d$aat3.miss==0] <- exp(9)

d$mpo1Delta <- d$mpo1
d$mpo1Delta[d$mpo1.miss==0] <- exp(9)

d$mpo2Delta <- d$mpo2
d$mpo2Delta[d$mpo2.miss==0] <- exp(9)

d$mpo3Delta <- d$mpo3
d$mpo3Delta[d$mpo3.miss==0] <- exp(9)

d$neo1Delta <- d$neo1
d$neo1Delta[d$neo1.miss==0] <- exp(9)

d$neo2Delta <- d$neo2
d$neo2Delta[d$neo2.miss==0] <- exp(9)

d$neo3Delta <- d$neo3
d$neo3Delta[d$neo3.miss==0] <- exp(9)



#Order for replication:
d<-d[order(d$block,d$clusterid,d$childid),]
  

#Create empty matrix to hold the ipcw results:
res_adj<-list(neo_t1_adj=matrix(0,5,5), mpo_t1_adj=matrix(0,5,5), aat_t1_adj=matrix(0,5,5), 
                neo_t2_adj=matrix(0,5,5), mpo_t2_adj=matrix(0,5,5), aat_t2_adj=matrix(0,5,5),  
                neo_t3_adj=matrix(0,5,5), mpo_t3_adj=matrix(0,5,5), aat_t3_adj=matrix(0,5,5))

Wlist <- list(W1,W1,W1,W2,W2,W2,W3,W3,W3)



for(i in 1:9){
  for(j in 1:5){
    #note the log transformation of the outcome prior to running GLM model:
    temp<-washb_tmle(Y=log(Y[,i]), Delta=miss[,i], tr=d$tr, W=Wlist[[i]], id=d$block, pair=NULL, family="gaussian", contrast= contrasts[[j]], Q.SL.library = c("SL.glm"), seed=12345, print=T)
    cat(i," : ",j, "\n")
    res_adj[[i]][j,]<-(t(unlist(temp$estimates$ATE)))
    colnames(res_adj[[i]])<-c("psi","var.psi","ci.l","ci.u", "Pval")
    rownames(res_adj[[i]])<-c(c("Control v WSH", "Control v Nutrition", "Control v Nutrition + WSH", "WSH v Nutrition + WSH", "Nutrition v Nutrition + WSH"))
  }
}



#Extract estimates
neo_t1_adj_ipcw_M<-res_adj[[1]]
neo_t2_adj_ipcw_M<-res_adj[[4]]
neo_t3_adj_ipcw_M<-res_adj[[7]]

mpo_t1_adj_ipcw_M<-res_adj[[2]]
mpo_t2_adj_ipcw_M<-res_adj[[5]]
mpo_t3_adj_ipcw_M<-res_adj[[8]]

aat_t1_adj_ipcw_M<-res_adj[[3]]
aat_t2_adj_ipcw_M<-res_adj[[6]]
aat_t3_adj_ipcw_M<-res_adj[[9]]





setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBB-EE-analysis/Results/Andrew/")
save(
aat_t1_adj_ipcw_M,
aat_t2_adj_ipcw_M,
aat_t3_adj_ipcw_M,
mpo_t1_adj_ipcw_M,
mpo_t2_adj_ipcw_M,
mpo_t3_adj_ipcw_M,
neo_t1_adj_ipcw_M,
neo_t2_adj_ipcw_M,
neo_t3_adj_ipcw_M,
file="stool_ipcw_res.Rdata")













#---------------------------------------
# EE-K-stool-ipcw.R
#
# andrew mertens (amertens@berkeley.edu)
#
# The analysis script for the WASH Benefits
# EED substudy -IPCW analysis for missing 
# outcomes of stool-based biomarkers
#---------------------------------------

###Load in data
rm(list=ls())
library(tidyverse)
library(foreign)
library(washb)
library(lubridate)


#Load in blinded treatment information
setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew")
#tr <- read.csv("raw CSV/washk_blindTR.csv")
tr <- read.csv("raw CSV/washk_TR.csv")
tr$tr <- factor(tr$tr, levels = c("Control",  "WSH", "Nutrition", "Nutrition + WSH"))
head(tr)

#Child dates of birth
dob <- readRDS("WBK-EE-childDOB.rds")

#Stool outcomes
outcomes<-read.csv("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew/raw CSV/washk_ee_stool.csv")
head(outcomes)



#Stool collection dates and staffid
load("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew/washk_ee_stool_survey.Rdata")


#Rename outcomes:
outcomes <- outcomes %>%
  rename(aat1=t1_aat,
         aat2=t2_aat,
         aat3=t3_aat,
         mpo1=t1_mpo,
         mpo2=t2_mpo,
         mpo3=t3_mpo,
         neo1=t1_neo,
         neo2=t2_neo,
         neo3=t3_neo)

#Baseline covariates
enrol <- readRDS("WBK-EE-covariates.rds")
head(enrol)

d <- left_join(outcomes, dob, by="childid")

d <- left_join(d, stsurv, by="childid")

d <- left_join(d, enrol, by="hhid")

d <- left_join(d, tr, by="clusterid")




#Load in enrollment data for adjusted analysis
setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Temp/")
enrol<-read.csv("washb-bangladesh-enrol+animals.csv",stringsAsFactors = TRUE)


setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Data/Cleaned/Andrew")
stool<-read.csv("BD-EE-stool.csv")
ipcw<-read.csv("BD-EE-ipcw.csv", stringsAsFactors = T) %>% select(-c(tr,block))





#Subset to EED arms
d<-subset(d, tr=="Control" | tr=="WSH" | tr=="Nutrition" | tr=="Nutrition + WSH")


#Impute time varying covariates

#set staffid and month to missing if missing stool samples
no_outcome <- is.na(d$aat1) & is.na(d$aat2) & is.na(d$aat3) & is.na(d$reg1b2) & 
                is.na(d$mpo1) & is.na(d$mpo2) & is.na(d$mpo3) & 
                is.na(d$neo1) & is.na(d$neo2) & is.na(d$neo3)
d$staffid1[no_outcome & !is.na(d$staffid1)] <- NA
d$staffid2[no_outcome & !is.na(d$staffid2)] <- NA 
d$staffid3[no_outcome & !is.na(d$staffid3)] <- NA 
d$month1[no_outcome & !is.na(d$month1)] <- NA
d$month2[no_outcome & !is.na(d$month2)] <- NA 
d$month3[no_outcome & !is.na(d$month3)] <- NA 
d$aged1[no_outcome & !is.na(d$aged1)] <- NA
d$aged2[no_outcome & !is.na(d$aged2)] <- NA 
d$aged3[no_outcome & !is.na(d$aged3)] <- NA 


#calculate overall median:
month1_median <-    median(d$month1, na.rm = T)
month2_median <-    median(d$month2, na.rm = T)
month3_median <-    median(d$month3, na.rm = T)

#use clusterid to impute median month where possible
table(d$month1)
table(is.na(d$month1))
d$month1[is.na(d$month1)] <-  ave(d$month1, d$clusterid, FUN=function(x) median(x, na.rm = T))[is.na(d$month1)] 
d$month1 <- ceiling(d$month1)
table(d$month1)
table(d$month1[d$tr=="Control"])


d$month2[is.na(d$month2)] <-  ave(d$month2, d$clusterid, FUN=function(x) median(x, na.rm = T))[is.na(d$month2)] 
d$month2 <- ceiling(d$month2)

d$month3[is.na(d$month3)] <-  ave(d$month3, d$clusterid, FUN=function(x) median(x, na.rm = T))[is.na(d$month3)] 
d$month3 <- ceiling(d$month3)


#impute month with overall median for those observations not in a cluster measured in the EED subsample
d$month1[is.na(d$month1)] <-  7
d$month2[is.na(d$month2)] <-  8
d$month3[is.na(d$month3)] <-  6


d <- d %>% mutate(monsoon1 = ifelse(month1 > 4 & month1 < 11, "1", "0"),
                  monsoon2 = ifelse(month2 > 4 & month2 < 11, "1", "0"),
                  monsoon3 = ifelse(month3 > 4 & month3 < 11, "1", "0"),
                  monsoon1 = ifelse(is.na(month1),"missing", monsoon1),
                  monsoon2 = ifelse(is.na(month2),"missing", monsoon2),
                  monsoon3 = ifelse(is.na(month3),"missing", monsoon3),
                  monsoon1 = factor(monsoon1),
                  monsoon2 = factor(monsoon2),
                  monsoon3 = factor(monsoon3))


#impute child age with overall median
d$aged1[is.na(d$aged1)] <- 84
d$aged2[is.na(d$aged2)] <- 428
d$aged3[is.na(d$aged3)] <- 857


#Clean covariates for adjusted analysis
#Set birthorder to 1, >=2, or missing
class(d$birthord)
d$birthord[d$birthord>1]<-"2+"
d$birthord[is.na(d$birthord)]<-"missing"
d$birthord<-factor(d$birthord)

#Make vectors of adjustment variable names
Wvars<-c('sex', 'birthord',
         'momage', 'momheight','momedu','hfiacat',
         'Nlt18','Ncomp','watmin',
          'walls', 'floor',
         'elec', 'asset_wardrobe', 'asset_table', 'asset_chair', 'asset_clock', 
         'asset_khat', 'asset_chouki', 'asset_radio', 
         'asset_tv', 'asset_refrig', 'asset_bike',
         'asset_moto', 'asset_sewmach', 'asset_mobile',
         'n_cows', 'n_goats', 'n_chickens')


df<-d
save(df, file="C:/Users/andre/Downloads/temp_a.Rdata")

#subset time-constant W adjustment set
W<- subset(d, select=Wvars)

#Clean adjustment variables 
#Check missingness
for(i in 1:ncol(W)){
  print(colnames(W)[i])
  print(table(is.na(W[,i])))
}

#Replace missingness for factors with new level
#in main dataset 
d$sex<-as.factor(d$sex)
d$birthord<-factor(d$birthord)
table(d$birthord)
table(W$birthord)

d %>% group_by(birthord) %>% summarise(mean=mean(log(aat3), na.rm=T))

d$asset_clock[is.na(d$asset_clock)]<-"99"
d$asset_clock<-factor(d$asset_clock)

#Order data to replicate SL
d <- d[order(d$dataid,d$childNo, d$svy),]

#Re-subset W so new missing categories are included
W<- subset(d, select=Wvars)

#check that all the factor variables are set
for(i in 1:ncol(W)){
  print(colnames(W)[i])
  print(class(W[,i])  )
}


#Truncate unrealistic levels of n_chickens to 60
table(d$n_chickens)
d$n_chickens[d$n_chickens>60]<-60
table(d$n_chickens)




#Relevel all factors
table(d$sex)
d$sex<-addNA(d$sex)
  levels(d$sex)[3]<-"missing"
table(d$sex)
d$momedu=relevel(d$momedu,ref="No education")
d$hfiacat=relevel(d$hfiacat,ref="Food Secure")
    d$hfiacat<-addNA(d$hfiacat)
d$wall<-factor(d$wall)
    d$wall<-addNA(d$wall)
    levels(d$wall)<-c("No improved wall","Improved wall","Missing")
    d$wall=relevel(d$wall,ref="No improved wall")
d$floor<-factor(d$floor)
    d$floor<-addNA(d$floor)
    levels(d$floor)<-c("No improved floor","Improved floor","Missing")
    d$floor=relevel(d$floor,ref="No improved floor")
d$elec<-factor(d$elec)
    d$elec<-addNA(d$elec)
    levels(d$elec)<-c("No electricity","Electricity","Missing")
    d$elec=relevel(d$elec,ref="No electricity")
d$asset_wardrobe<-factor(d$asset_wardrobe)
    d$asset_wardrobe<-addNA(d$asset_wardrobe)
    levels(d$asset_wardrobe)<-c("No wardrobe","Wardrobe","Missing")
    d$asset_wardrobe=relevel(d$asset_wardrobe,ref="No wardrobe")
d$asset_table<-factor(d$asset_table)
    d$asset_table<-addNA(d$asset_table)
    levels(d$asset_table)<-c("No table","Improved table","Missing")
    d$asset_table=relevel(d$asset_table,ref="No table")
d$asset_chair<-factor(d$asset_chair)
    d$asset_chair<-addNA(d$asset_chair)
    levels(d$asset_chair)<-c("No chair","Chair","Missing")
    d$asset_chair=relevel(d$asset_chair,ref="No chair")
d$asset_clock[is.na(d$asset_clock)]<-99
    d$asset_clock<-factor(d$asset_clock)
    d$asset_clock<-addNA(d$asset_clock)
    levels(d$asset_clock)<-c("No clock","Clock","Missing", "Missing")
    d$asset_clock=relevel(d$asset_clock,ref="No clock")
d$asset_khat<-factor(d$asset_khat)
    d$asset_khat<-addNA(d$asset_khat)
    levels(d$asset_khat)<-c("No khat","Khat","Missing")
    d$asset_khat=relevel(d$asset_khat,ref="No khat")
d$asset_chouki<-factor(d$asset_chouki)
    d$asset_chouki<-addNA(d$asset_chouki)
    levels(d$asset_chouki)<-c("No chouki","Chouki","Missing")
    d$asset_chouki=relevel(d$asset_chouki,ref="No chouki")
d$asset_tv<-factor(d$asset_tv)
    d$asset_tv<-addNA(d$asset_tv)
    levels(d$asset_tv)<-c("No TV","Improved TV","Missing")
    d$asset_tv=relevel(d$asset_tv,ref="No TV")
d$asset_refrig<-factor(d$asset_refrig)
    d$asset_refrig<-addNA(d$asset_refrig)
    levels(d$asset_refrig)<-c("No refrigerator","Refrigerator","Missing")
    d$asset_refrig=relevel(d$asset_refrig,ref="No refrigerator")
d$asset_bike<-factor(d$asset_bike)
    d$asset_bike<-addNA(d$asset_bike)
    levels(d$asset_bike)<-c("No bicycle","Bicycle","Missing")
    d$asset_bike=relevel(d$asset_bike,ref="No bicycle")
d$asset_moto<-factor(d$asset_moto)
    d$asset_moto<-addNA(d$asset_moto)
    levels(d$asset_moto)<-c("No motorcycle","Motorcycle","Missing")
    d$asset_moto=relevel(d$asset_moto,ref="No motorcycle")
d$asset_sewmach<-factor(d$asset_sewmach)
    d$asset_sewmach<-addNA(d$asset_sewmach)
    levels(d$asset_sewmach)<-c("No sewing machine","Sewing machine","Missing")
    d$asset_sewmach=relevel(d$asset_sewmach,ref="No sewing machine")
d$asset_mobile<-factor(d$asset_mobile)
    d$asset_mobile<-addNA(d$asset_mobile)
    levels(d$asset_mobile)<-c("No mobile phone","Mobile phone","Missing")
    d$asset_mobile=relevel(d$asset_mobile,ref="No mobile phone")    

#Re-subset W so new re-leveled factors are included
W<- subset(d, select=Wvars)


#Add in time-varying covariates
Wvars1<-c("aged1", "monsoon1") 
Wvars2<-c("aged2", "monsoon2") 
Wvars3<-c("aged3", "monsoon3") 
W1<- cbind(W, subset(d, select=Wvars1))
W2<- cbind(W, subset(d, select=Wvars2))
W3<- cbind(W, subset(d, select=Wvars3))

#Replace missingness in time varying covariates as a new level
W1$monsoon1[is.na(W1$monsoon1)]<-"missing"
W2$monsoon2[is.na(W2$monsoon2)]<-"missing"
W3$monsoon3[is.na(W3$monsoon3)]<-"missing"





#Create indicators for missingness
d$aat1.miss<-ifelse(is.na(d$aat1),0,1)
d$aat2.miss<-ifelse(is.na(d$aat2),0,1)
d$aat3.miss<-ifelse(is.na(d$aat3),0,1)

d$mpo1.miss<-ifelse(is.na(d$mpo1),0,1)
d$mpo2.miss<-ifelse(is.na(d$mpo2),0,1)
d$mpo3.miss<-ifelse(is.na(d$mpo3),0,1)

d$neo1.miss<-ifelse(is.na(d$neo1),0,1)
d$neo2.miss<-ifelse(is.na(d$neo2),0,1)
d$neo3.miss<-ifelse(is.na(d$neo3),0,1)

d$reg1b2.miss<-ifelse(is.na(d$reg1b2),0,1)


table(d$aat1.miss)
table(d$aat2.miss)
table(d$aat3.miss)

table(d$mpo1.miss)
table(d$mpo2.miss)
table(d$mpo3.miss)

table(d$neo1.miss)
table(d$neo2.miss)
table(d$neo3.miss)

table(d$reg1b2.miss)

table(d$aat1.miss)
table(d$aat2.miss)
table(d$aat3.miss)


d$aat3Delta.test <- log(d$aat3)
d$aat3Delta.test[d$aat3.miss==0] <- 99


# set missing outcomes to an arbitrary, non-missing value. In this case use 9
d$aat1Delta <- d$aat1
d$aat1Delta[d$aat1.miss==0] <- exp(9)

d$aat2Delta <- d$aat2
d$aat2Delta[d$aat2.miss==0] <- exp(9)

d$aat3Delta <- d$aat3
d$aat3Delta[d$aat3.miss==0] <- exp(9)

d$mpo1Delta <- d$mpo1
d$mpo1Delta[d$mpo1.miss==0] <- exp(9)

d$mpo2Delta <- d$mpo2
d$mpo2Delta[d$mpo2.miss==0] <- exp(9)

d$mpo3Delta <- d$mpo3
d$mpo3Delta[d$mpo3.miss==0] <- exp(9)

d$neo1Delta <- d$neo1
d$neo1Delta[d$neo1.miss==0] <- exp(9)

d$neo2Delta <- d$neo2
d$neo2Delta[d$neo2.miss==0] <- exp(9)

d$neo3Delta <- d$neo3
d$neo3Delta[d$neo3.miss==0] <- exp(9)

d$reg1b2Delta <- d$reg1b2
d$reg1b2Delta[d$reg1b2.miss==0] <- exp(9)




#Order for replication:
d<-d[order(d$block,d$clusterid,d$dataid),]
  
#Run the unadjusted ipcw analysis


#Create empty matrix to hold the glm results:
neo_t1_unadj<-mpo_t1_unadj<-aat_t1_unadj<-matrix(0, nrow=5, ncol=5)
neo_t2_unadj<-mpo_t2_unadj<-aat_t2_unadj<-reg1b_t2_unadj<-matrix(0, nrow=5, ncol=5)
neo_t3_unadj<-mpo_t3_unadj<-aat_t3_unadj<-matrix(0, nrow=5, ncol=5)

res_unadj<-list(neo_t1_unadj=neo_t1_unadj, mpo_t1_unadj=mpo_t1_unadj, aat_t1_unadj=aat_t1_unadj, 
                neo_t2_unadj=neo_t2_unadj, mpo_t2_unadj=mpo_t2_unadj, aat_t2_unadj=aat_t2_unadj, reg1b_t2_unadj=reg1b_t2_unadj, 
                neo_t3_unadj=neo_t3_unadj, mpo_t3_unadj=mpo_t3_unadj, aat_t3_unadj=aat_t3_unadj)




#Unadjusted glm models

#dataframe of stool biomarkers:
Y<-d %>% select(neo1Delta,mpo1Delta,aat1Delta,neo2Delta,mpo2Delta,aat2Delta,reg1b2Delta,neo3Delta,mpo3Delta,aat3Delta)

#dataframe of stool missingness:
miss<-d %>% select(neo1.miss,mpo1.miss,aat1.miss,neo2.miss,mpo2.miss,aat2.miss,reg1b2.miss,neo3.miss,mpo3.miss,aat3.miss)


#Set contrasts:
contrasts <- list(c("Control","WSH"), c("Control","Nutrition"), c("Control","Nutrition + WSH"), c("WSH","Nutrition + WSH"), c("Nutrition","Nutrition + WSH"))



for(i in 1:10){
  for(j in 1:5){
    #note the log transformation of the outcome prior to running GLM model:
    temp<-washb_tmle(Y=log(Y[,i]), Delta=miss[,i], tr=d$tr, W=NULL, id=d$block, pair=NULL, family="gaussian", contrast= contrasts[[j]], Q.SL.library = c("SL.glm"), seed=12345, print=T)
    cat(i," : ",j, "\n")
    res_unadj[[i]][j,]<-(t(unlist(temp$estimates$ATE)))
    colnames(res_unadj[[i]])<-c("psi","var.psi","ci.l","ci.u", "Pval")
    rownames(res_unadj[[i]])<-c(c("Control v WSH", "Control v Nutrition", "Control v Nutrition + WSH", "WSH v Nutrition + WSH", "Nutrition v Nutrition + WSH"))
  }
}

#Extract estimates

neo_t1_unadj_ipcw_M<-res_unadj[[1]]
neo_t2_unadj_ipcw_M<-res_unadj[[4]]
neo_t3_unadj_ipcw_M<-res_unadj[[8]]

mpo_t1_unadj_ipcw_M<-res_unadj[[2]]
mpo_t2_unadj_ipcw_M<-res_unadj[[5]]
mpo_t3_unadj_ipcw_M<-res_unadj[[9]]

aat_t1_unadj_ipcw_M<-res_unadj[[3]]
aat_t2_unadj_ipcw_M<-res_unadj[[6]]
aat_t3_unadj_ipcw_M<-res_unadj[[10]]

reg_t2_unadj_ipcw_M<-res_unadj[[7]]





#Create empty matrix to hold the glm results:


res_adj<-list(neo_t1_adj=matrix(0,5,5), mpo_t1_adj=matrix(0,5,5), aat_t1_adj=matrix(0,5,5), 
                neo_t2_adj=matrix(0,5,5), mpo_t2_adj=matrix(0,5,5), aat_t2_adj=matrix(0,5,5),  reg1b_t2_adj=matrix(0,5,5),
                neo_t3_adj=matrix(0,5,5), mpo_t3_adj=matrix(0,5,5), aat_t3_adj=matrix(0,5,5))

Wlist <- list(W1,W1,W1,W2,W2,W2,W2,W3,W3,W3)


 i<-6
 j <- 3
mean(log(Y[d$tr=="Control",i]), na.rm=T)
sum(miss[d$tr=="Control",i], na.rm=T)
mean(log(Y[d$tr=="WSH",i]), na.rm=T)
sum(miss[d$tr=="WSH",i], na.rm=T)
temp<-washb_tmle(Y=log(Y[,i]), Delta=miss[,i], tr=d$tr, W=Wlist[[i]], id=d$block, pair=NULL, family="gaussian", contrast= contrasts[[j]], Q.SL.library = c("SL.glm"), seed=12345, print=T)


d %>% group_by(tr) %>% summarize(aat2=mean(log(aat2Delta), na.rm=T))


temp<-washb_tmle(Y=log(Y[,i]), Delta=miss[,i], tr=d$tr,
                 W=select(Wlist[[i]], -contains("month")), 
                 id=d$block, pair=NULL, family="gaussian", contrast= contrasts[[j]], Q.SL.library = c("SL.glm"), seed=12345, print=T)



# d <- d[(d$tr=="Control" | d$tr=="Nutrition + WSH") & !is.na(d$tr),]
# summary(d$aged1)


for(i in 1:10){
  for(j in 1:5){
    #note the log transformation of the outcome prior to running GLM model:
    temp<-washb_tmle(Y=log(Y[,i]), Delta=miss[,i], tr=d$tr, W=Wlist[[i]], id=d$block, pair=NULL, family="gaussian", contrast= contrasts[[j]], Q.SL.library = c("SL.glm"), seed=12345, print=T)
    cat(i," : ",j, "\n")
    res_adj[[i]][j,]<-(t(unlist(temp$estimates$ATE)))
    colnames(res_adj[[i]])<-c("psi","var.psi","ci.l","ci.u", "Pval")
    rownames(res_adj[[i]])<-c(c("Control v WSH", "Control v Nutrition", "Control v Nutrition + WSH", "WSH v Nutrition + WSH", "Nutrition v Nutrition + WSH"))
  }
}



#Extract estimates
neo_t1_adj_ipcw_M<-res_adj[[1]]
neo_t2_adj_ipcw_M<-res_adj[[4]]
neo_t3_adj_ipcw_M<-res_adj[[8]]

mpo_t1_adj_ipcw_M<-res_adj[[2]]
mpo_t2_adj_ipcw_M<-res_adj[[5]]
mpo_t3_adj_ipcw_M<-res_adj[[9]]

aat_t1_adj_ipcw_M<-res_adj[[3]]
aat_t2_adj_ipcw_M<-res_adj[[6]]
aat_t3_adj_ipcw_M<-res_adj[[10]]

reg_t2_adj_ipcw_M<-res_adj[[7]]




setwd("C:/Users/andre/Dropbox/WASHB-EE-analysis/WBK-EE-analysis/Results/Andrew/")
save(aat_t1_unadj_ipcw_M,
aat_t2_unadj_ipcw_M,
aat_t3_unadj_ipcw_M,
mpo_t1_unadj_ipcw_M,
mpo_t2_unadj_ipcw_M,
mpo_t3_unadj_ipcw_M,
neo_t1_unadj_ipcw_M,
neo_t2_unadj_ipcw_M,
neo_t3_unadj_ipcw_M,
reg_t2_unadj_ipcw_M,
aat_t1_adj_ipcw_M,
aat_t2_adj_ipcw_M,
aat_t3_adj_ipcw_M,
mpo_t1_adj_ipcw_M,
mpo_t2_adj_ipcw_M,
mpo_t3_adj_ipcw_M,
neo_t1_adj_ipcw_M,
neo_t2_adj_ipcw_M,

neo_t3_adj_ipcw_M,
reg_t2_adj_ipcw_M, 
file="stool_ipcw_res.Rdata")




