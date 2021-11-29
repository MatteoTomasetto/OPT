##############################################################################
############################### Pre-processing ###############################
##############################################################################

library(medicaldata)
df <- medicaldata::opt
setwd("C:/Users/matte/Desktop/NonParam_OPT_Project")
source("DATA PREPROCESSING.R")

##############################################################################
################################ FUNCTIONS ###################################
##############################################################################

library(MASS)
library(rgl)
library(DepthProc)
library(hexbin)
library(packagefinder)
library(aplpack)
library(robustbase)
library(progress)

perm_t_test_mean = function(x,y,iter=1e3){
  T0=abs(mean(x)-mean(y))  
  T_stat=numeric(iter)
  x_pooled=c(x,y)
  n=length(x_pooled)
  n1=length(x)
  for(perm in 1:iter){
    # permutation:
    permutation <- sample(1:n)
    x_perm <- x_pooled[permutation]
    x1_perm <- x_perm[1:n1]
    x2_perm <- x_perm[(n1+1):n]
    # test statistic:
    T_stat[perm] <- abs(mean(x1_perm) - mean(x2_perm))
    
  }
  # p-value
  p_val <- sum(T_stat>=T0)/iter
  
  return(p_val)
}

perm_t_test_median = function(x,y,iter=1e3){
  T0=abs(median(x)-median(y))  
  T_stat=numeric(iter)
  x_pooled=c(x,y)
  n=length(x_pooled)
  n1=length(x)
  for(perm in 1:iter){
    # permutation:
    permutation <- sample(1:n)
    x_perm <- x_pooled[permutation]
    x1_perm <- x_perm[1:n1]
    x2_perm <- x_perm[(n1+1):n]
    # test statistic:
    T_stat[perm] <- abs(median(x1_perm) - median(x2_perm))
    
  }
  # p-value
  p_val <- sum(T_stat>=T0)/iter
  
  return(p_val)
}

perm_t_test_depth = function(x,y,iter=1e3){
  x_med=depthMedian(as.matrix(x),depth_params = list(method='Tukey'))
  y_med=depthMedian(as.matrix(y),depth_params = list(method='Tukey'))  
  T0=as.numeric((x_med-y_med) %*% (x_med-y_med))
  T_stat=numeric(iter)
  x_pooled=rbind(x,y)
  n=dim(x_pooled)[1]
  n1=dim(x)[1]
  for(perm in 1:iter){
    # permutation:
    permutation <- sample(1:n)
    x_perm <- x_pooled[permutation,]
    x1_perm <- x_perm[1:n1,]
    x2_perm <- x_perm[(n1+1):n,]
    # test statistic:
    x1_med=depthMedian(as.matrix(x1_perm),depth_params = list(method='Tukey'))
    x2_med=depthMedian(as.matrix(x2_perm),depth_params = list(method='Tukey'))  
    T_stat[perm]=as.numeric((x1_med-x2_med) %*% (x1_med-x2_med))
  }
  # p-value
  p_val <- sum(T_stat>=T0)/iter
  
  return(p_val)
}

perm_t_test_prop = function(x,y,iter=1e3){
  T_stat=numeric(iter)
  x_pooled=factor(c(x,y))
  n=length(x_pooled)
  n1=length(x)
  T0=abs(sum(x==levels(x)[2])/n1-sum(y==levels(y)[2])/(n-n1))  # Difference of percentages of the occurrences of a factor in the 2 groups 
  for(perm in 1:iter){
    # permutation:
    permutation <- sample(1:n)
    x_perm <- x_pooled[permutation]
    x1_perm <- x_perm[1:n1]
    x2_perm <- x_perm[(n1+1):n]
    # test statistic:
    T_stat[perm] <- abs(sum(x1_perm==levels(x1_perm)[1])/n1-sum(x2_perm==levels(x2_perm)[1])/(n-n1))
  }
  # p-value
  p_val <- sum(T_stat>=T0)/iter
  
  return(p_val)
}

perm_t_test_mean_multivariate = function(x,y,iter=1e3){
  T0=as.numeric((colMeans(x)-colMeans(y)) %*% (colMeans(x)-colMeans(y)))
  T_stat=numeric(iter)
  x_pooled=rbind(x,y)
  n=dim(x_pooled)[1]
  n1=dim(x)[1]
  for(perm in 1:iter){
    # permutation:
    permutation <- sample(1:n)
    x_perm <- x_pooled[permutation,]
    x1_perm <- x_perm[1:n1,]
    x2_perm <- x_perm[(n1+1):n,]
    # test statistic:
    T_stat[perm] <- as.numeric((colMeans(x1_perm)-colMeans(x2_perm)) %*% (colMeans(x1_perm)-colMeans(x2_perm)))  
  }
  # p-value
  p_val <- sum(T_stat>=T0)/iter
  
  return(p_val)
}

perm_anova = function(outcome,group,iter=1e3){
  fit <- aov(outcome ~ group)
  T0 <- summary(fit)[[1]][1,4]
  T_stat <- numeric(iter)
  n <- length(outcome)
  for(perm in 1:iter){
  # Permutation:
  permutation <- sample(1:n)
  outcome_perm <- outcome[permutation]
  fit_perm <- aov(outcome_perm ~ group)
  # Test statistic:
  T_stat[perm] <- summary(fit_perm)[[1]][1,4]
  }
  #pvalue
  p_val <- sum(T_stat>=T0)/iter
  return(p_val) 
}

perm_manova = function(outcome,group,iter=1e3){
  fit <- manova(as.matrix(outcome) ~ group)
  T0 <- -summary.manova(fit,test="Wilks")$stats[1,2]
  T_stat <- numeric(iter)
  n <- dim(outcome)[1]
  for(perm in 1:iter){
    # Permutation:
    permutation <- sample(1:n)
    outcome_perm <- outcome[permutation,]
    fit_perm <- manova(as.matrix(outcome_perm) ~ group)
    # Test statistic:
    T_stat[perm] <- -summary.manova(fit_perm,test="Wilks")$stats[1,2]
  }
  #pvalue
  p_val <- sum(T_stat>=T0)/iter
  return(p_val) 
}

##############################################################################
############################## T-test univariate #############################
##############################################################################

idx_Var = 71
idx_NA = which(is.na(df[,idx_Var]))
if (length(idx_NA)==0){
  Var_test = df[,idx_Var]
  Group_test = df[,3]
  x = Var_test[which(Group_test =='C')]
  y = Var_test[which(Group_test =='T')]
} else {
  Var_test = df[-idx_NA,idx_Var]
  Group_test = df[-idx_NA,3]
  x = Var_test[which(Group_test =='C')]
  y = Var_test[which(Group_test =='T')]
}

# Set threshold for numerical variable if wanted
threshold = 240 # 240 per delivery time, 2000 per birth weight
x = x[which(x <= threshold)]
y = y[which(y <= threshold)]

if(is.factor(df[,idx_Var])==TRUE){
  perm_t_test_prop(x,y) 
} else {
  x11()
  boxplot(x,main="Control")
  x11()
  boxplot(y,main="Treatment")
  
  perm_t_test_mean(x,y)
  perm_t_test_median(x,y)
  perm_anova(Var_test, Group_test)
}


##############################################################################
############################## T-test bivariate ##############################
##############################################################################

idx_Var = c(71,72)
idx_NA = c(which(is.na(df[,idx_Var[1]])),which(is.na(df[,idx_Var[2]])))
idx_NA = sort(unique(idx_NA))
if (length(idx_NA)==0){
  Var_test = df[,idx_Var]
  Group_test = df[,3]
  x = Var_test[which(Group_test =='C'),]
  y = Var_test[which(Group_test =='T'),]
} else {
  Var_test = df[-idx_NA,idx_Var]
  Group_test = df[-idx_NA,3]
  x = Var_test[which(Group_test =='C'),]
  y = Var_test[which(Group_test =='T'),]
}

# Set threshold for both numerical variables if wanted
threshold1 = 240
threshold2 = 2000
x = x[which(x[,1] <= threshold1 & x[,2] <= threshold2),]
y = y[which(y[,1] <= threshold1 & y[,2] <= threshold2),]

# Set threshold for only 1 numerical variable if wanted
threshold = 240
idx_threshold = 1 # 1 or 2 in the bivariate case
x = x[which(x[,idx_threshold] <= threshold1),]
y = y[which(y[,idx_threshold] <= threshold1),]

x11()
boxplot(x,main="Control")
x11()
boxplot(y,main="Treatment")

perm_t_test_mean_multivariate(x,y)
perm_t_test_depth(x,y,iter=250) # this could be slow
perm_manova(Var_test,Group_test)