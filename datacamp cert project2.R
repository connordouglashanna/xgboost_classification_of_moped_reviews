# Analysis for R certification
#### update the data validation section
#### update the data exploration section
#### make sure the pipeline of moped_NA to the analysis runs correctly


# Loading packages
library(tidyverse)
library(ggplot2)
library(moments)
library(ggthemes)
library(colorspace)
library(caret)
library(broom)
library(ggrepel)
library(xgboost)
library(rsample)
library(forcats)
library(ggforce)
library(vtreat)
library(WVPlots)
library(pROC)

# Importing data from csv
moped <- read_csv("School/datacamp/Datacamp-Cert-Project-2/moped.csv")

# cleaning
#####

# Inspecting data for variables to ensure we're not missing anything
head(moped)

# all present and accounted for
# varnames all have quotation marks though, those are hideous

# renaming variables
moped <- 
moped %>% 
  mutate(used_for = `Used it for`,
         duration_owned = `Owned for`,
         model = `Model Name`,
         visual_appeal = `Visual Appeal`,
         extra_features = `Extra Features`,
         maint_cost = `Maintenance cost`,
         value = `Value for Money`,
         reliability = Reliability,
         comfort = Comfort,
         .keep = "unused") 

# corrected some capital letters too. naming is now consistent. 

# now to correct issues mentioned in the documentation
# "owned for" ownership column should be changed to indicate ownership as a dummy

# checking for pre-modification status
table(moped$duration_owned)

# generating new variable from duration_owned to match documentation
moped <- 
  moped %>%
  mutate(text_owned = ifelse(duration_owned == "Never owned", 
                        duration_owned, 
                        "Owned")) 

# generating new dummy variable for use when appropriate
moped <- 
  moped |>
  mutate(owned = ifelse(duration_owned == "Never owned", 0, 1),
         .keep = "unused")

# storing the original moped df for when I want the NAs for vtreat
moped_NA <- moped |>
  # removing the duration_owned variable since it won't be needed for analysis
              select(-text_owned)

# rechecking compared to post-modification status
table(moped$owned)

# checking other variables for NA values
# storing for use later validating manipulation prior to analysis
(NAtable <- 
  colSums(is.na(moped)))

# this matches the documentation for variables requiring NA replacement
# now to perform replacements individually
  # extra_features
  moped <- 
    moped |>
    mutate(extra_features = ifelse(is.na(extra_features) == T, 0, extra_features), .keep = "unused")
  
  # checking results
  table(moped$extra_features)
  
  # maint_cost  
  moped <- 
    moped |>
    mutate(maint_cost = ifelse(is.na(maint_cost) == T, 0, maint_cost), .keep = "unused")

  # checking results 
  table(moped$maint_cost)
  
  # value
  moped <-
    moped |>
    mutate(value = ifelse(is.na(value) == T, 0, value), .keep = "unused")
  
  # checking results
  table(moped$value)
  
  # comfort 
  moped <- 
    moped |>
    mutate(comfort = ifelse(is.na(comfort) == T, 0, comfort), .keep = "unused")
  
  # checking results 
  table(moped$comfort)
  
# checking to make sure we've replaced all NA values
colSums(is.na(moped))
  
# checking to ensure that our new 0 values reflect prior NA values
(Zerotable <-
  colSums(moped == 0))

(replacement_test <- 
  Zerotable == NAtable)
  
# all variables match except owned
# owned is a dummy variable so this makes sense

# double checking the other variables against criteria
# visual_appeal
table(moped$visual_appeal)

# reliability
table(moped$reliability)

# model 
table(moped$model)

# used_for
table(moped$used_for)

# owned 
table(moped$owned)

# text_owned
table(moped$text_owned)
  
# checking for entries outside expected values
summary(moped)

# exploratory analysis
#####

# One density plot
moped |> 
  ggplot(aes(
    comfort, fill = "#440154FF"
  )) + 
  geom_density() + 
  labs(
    title = "Density plot of comfort ratings in moped reviews",
    x = "Comfort",
    y = "Density"
  ) + 
  theme_minimal() + 
  scale_fill_viridis_d() +
  theme(legend.position = "none")

# density bars of all numerical variables, sorted by ownership
  # pivot longer
  moped %>%
    pivot_longer(visual_appeal:comfort) %>%
    select(value, name, text_owned) %>%
  # recoding names of variables for facet titles
    mutate(name = recode(name,
                         "comfort" = "Comfort",
                         "extra_features" = "Extra features",
                         "maint_cost" = "Maintenance cost",
                         "reliability" = "Reliability", 
                         "value" = "Value", 
                         "visual_appeal" = "Visual appeal")) %>%
  # only NA values encoded to 0, we'll leave those out
    filter(value > 0) %>%
  # plot generation
  ggplot(aes(
    value, fill = text_owned, alpha = 0.9
  )) + 
    geom_histogram(breaks = seq(0.5, 5.5, 1), position = "identity", aes(y = ..density..)) + 
    facet_wrap(vars(name), scales = "free_y") + 
    labs(
      title = "Density histogram of ratings, faceted by category, colored by ownership",
      x = "Rating",
      y = "Density", 
      fill = "Ownership"
    ) + 
    guides(fill = "legend", alpha = "none") + 
    scale_fill_manual(values = c(
      'Never owned' = '#EE6A50',
      'Owned' = '#87CEFA'
    ))
      
#proportion of ownership across dataframe
moped |>
  summarize(prop_owned = mean(owned), n = n()) |>
  arrange(prop_owned)

# proportion of ownership by use 
moped %>%
  mutate(commuter = ifelse(used_for == "Commuting", 1, 0), .keep = "unused") |>
  group_by(commuter) %>%
  summarize(prop_owned = mean(owned), n = n()) %>%
  arrange(prop_owned)

# proportion of ownership by model
moped %>% 
  group_by(model) %>%
  summarize(prop_owned = mean(owned), n = n()) %>%
  arrange(prop_owned)

# pie plot to investigate ownership rate by model
  # generating a list of desired models
  model_list <- 
    moped |>
      group_by(model) |>
      summarize(n = n()) |>
      arrange(desc(n)) |>
      head(n = 20) |>
      pull(var = model) 

  # generating a table with clear aesthetic assignments for ggplot
  moped |>
    # culling low-n models using the list from earlier
    filter(model %in% model_list) |>
    group_by(model, text_owned) |>
    summarize(n = n()) |>
  # generating pie chart 
  ggplot(
    aes(
        x0 = 0, y0 = 0,
        r0 = 0, r = 1,
        amount = n,
        fill = text_owned,
      )
    ) + 
    geom_arc_bar(stat = "pie") + 
    theme_void() + 
    coord_fixed() + 
    labs(title = "Ownership proportion in moped reviews, by model", fill = "Reviewer ownership") + 
    facet_wrap(vars(model)) + 
    scale_fill_manual(values = c(
      'Never owned' = '#EE6A50',
      'Owned' = '#87CEFA'
    )) + 
    theme(
      panel.spacing = unit(0.5, "cm"),
      strip.text = element_text(size = 7)
    )
  
# PCA
  # arrow style object
  arrow_style <- arrow(
    angle = 20, length = grid::unit(8, "pt"),
    ends = "first", type = "closed")
  
  # generating PCA object
  pca_fit <- 
    moped %>%
    # recoding the use variable to a dummy
    mutate(commuter = ifelse(used_for == "Commuting", 1, 0)) %>% 
    # removing legacy/categorical variables
    select(-c(model, used_for, text_owned)) %>%
    na.omit() %>%
    scale() %>%
    prcomp()
  pca_fit
  
  # rotation matrix
  pca_fit |>
    tidy(matrix = "rotation") |>
    pivot_wider(
      names_from = "PC", values_from = "value",
      names_prefix = "PC"
    ) |>
    # biplot
    ggplot(aes(PC1, PC2)) +
    geom_segment(
      xend = 0, yend = 0,
      arrow = arrow_style
    ) +
    geom_text_repel(aes(label = column)) +
    xlim(-0.75, 0.75) + ylim(-1, 0.5) + 
    coord_fixed()
  
  # fetching the r-squared values for the principle components via eigenvalue plot
  pca_fit |>
    tidy(matrix = "eigenvalues") |>
    # scree plot
    ggplot(aes(PC, percent, fill = PC)) + 
    geom_col() + 
    scale_x_continuous(
      breaks = 1:8
    ) + 
    scale_y_continuous(
      name = "Variance Explained",
      label = scales::label_percent(accuracy = 1)
    ) + 
    scale_fill_viridis_c() +
    theme(legend.position = "none")
  
# bar graph of counts by model name
  moped |>
    ggplot(aes(
      fct_infreq(model), fill = after_stat(count)
    )) + 
    geom_bar() + 
    coord_flip() + 
    labs(
      title = "Total number of reviews for each moped model",
      x = "Model", 
      y = "Count"
    ) + 
    # including line showing the minimum count for inclusion as a group in splitting
    geom_hline(yintercept = 713 * .10, color = "#440154FF") + 
    theme_bw() + 
    scale_fill_viridis_c() + 
    theme(legend.position = "none") 
  
# counts by brand
  moped |> 
    separate(model, into = c("make", "model"), sep = "\\s", extra = "merge") |>
    ggplot(aes(
      fct_infreq(make), fill = after_stat(count)
    )) + 
    geom_bar() + 
    coord_flip() + 
    labs(
      title = "Total number of reviews for each moped manufacturer",
      x = "Make", 
      y = "Count"
    ) + 
    geom_hline(yintercept = 713 * .10, color = "#440154FF") + 
    theme_bw() + 
    scale_fill_viridis_c() + 
    theme(legend.position = "none") 
  
# bar graph of observations in makes vs models meeting the requirements
  # generating the desired summary stats
  model_n_1 <- 
    moped |>
    group_by(model) |>
    mutate(n = n()) |>
    filter(n > 71.3) |>
    count() |>
    mutate(make = NA)
  
  model_n_2 <- 
    moped |> 
    separate(model, into = c("make", "model"), sep = "\\s", extra = "merge") |>
    group_by(make) |>
    mutate(n = n()) |>
    filter(n > 71.3) |>
    count() |>
    mutate(model = NA)
  
  # forming final matrix of information
  model_n <- 
    rbind(model_n_1, model_n_2) |>
    mutate(type = ifelse(is.na(model) == TRUE, 1, 0),
           model = ifelse(type == 1, make, model)) |>
    select(-make) 
  # generating the bar graph 
  model_n |>
    ggplot(aes(
      as.factor(type), n, fill = model
    )) + 
    geom_col() + 
    labs(
      x = "Grouping",
      y = "Count", 
      title = "Captured observations by grouping type",
      fill = "Make/Model name"
    ) +
    scale_x_discrete(
      labels = c("Make", "Model")
    )
  
# examining balance of owned/not owned observations in the data
moped |> 
  group_by(text_owned) |> 
  summarize(n = n())
  
# predictive analysis
#####
# problem type is binary classification

# seed for replication
set.seed(100)
  ###https://win-vector.com/2017/04/15/encoding-categorical-variables-one-hot-and-beyond/
  
# manually converting one variable to a dummy
moped <-
  moped_NA |>
  mutate(commuter = ifelse(used_for == "Commuting", 1, 0), .keep = "unused")
  
# test/train split
split <-   
  initial_split(moped, prop = 0.8, strata = "model")

moped_train <- 
  training(split)

moped_test <- 
  testing(split)

# storing vtreat plan
treatplan <- designTreatmentsZ(moped_train, colnames(moped_train), minFraction = 1/10) 

# inspecting results
View(treatplan[["scoreFrame"]])

# executing treatment
train_treated <-  
  prepare(treatplan, moped_train) |>
  select(-model_catP)

test_treated <- 
  prepare(treatplan, moped_test)  |>
  select(-model_catP)

# log reg
  
  # model definition/training
  logreg_model_1 <- 
    glm(owned ~ ., data = train_treated, family = "binomial")
  
  logreg_model_1
  
  # summary of model
  summary(logreg_model_1)
  
  # test model
  test_treated$pred <- 
    predict(logreg_model_1, test_treated, type = "response")
  
  # saving this dataframe for later
  logreg_pred_1 <- 
    test_treated
    
# xgboost
  # defining dataframes sans outcome
    xgb_train <- 
      train_treated |>
      select(-owned) |>
      as.matrix()
      
    xgb_test <- 
      test_treated |>
      select(-c(pred, owned)) |>
      as.matrix()
      
  # running cross validation to find the ideal parameters
    cv <- xgb.cv(data = xgb_train, 
                 label = train_treated$owned,
                 nrounds = 100,
                 nfold = 5,
                 objective = "binary:logistic",
                 max_depth = 5,
                 early_stopping_rounds = 5, 
                 verbose = FALSE   # silent
      )
  # fetching evaluation log
    cv$evaluation_log |>
      summarize(ntrees.train = which.min(train_logloss_mean),
                ntrees.test = which.min(test_logloss_mean))
    
  # checking cross validation results using xgb.train()
  # generating appropriate matrices
  xgbDM_train <- 
    xgb.DMatrix(data = xgb_train, label = train_treated$owned)
    
  xgbDM_test <- 
    xgb.DMatrix(data = xgb_test, label = test_treated$owned)
  
  # generating watchlist
  watchlist <- 
    list(train = xgbDM_train, test = xgbDM_test)
  
  # running xgb.train() 
  xgb_training <- 
    xgb.train(
      data = xgbDM_train,
      max.depth = 5, 
      objective = "binary:logistic",
      watchlist = watchlist, 
      nrounds = 100,
      verbose = 0
    )
  
  # obtaining evaluation log
  xgb_training$evaluation_log |>
    summarize(ntrees.train = which.min(train_logloss),
              ntrees.test = which.min(test_logloss))
    
  # defining final model
  xgb_model_1 <- xgboost(data = xgb_train, 
                       label = train_treated$owned,
                       objective = "binary:logistic",
                       max.depth = 5, 
                       nrounds = 13, 
                       verbose = FALSE
                       )
  
  # predictions 
  test_treated$pred <- 
    predict(xgb_model_1, xgb_test, nrounds = 8)
  
  # saving for evaluation
  xgb_pred_1 <- 
    test_treated
  
  # saving colnames for evaluation
  colnames_1 <- 
    colnames(xgb_train)

# models without stratification
#####
# models without stratification
  # test/train split
  split <-   
    initial_split(moped, prop = 0.8)
  
  moped_train <- 
    training(split)
  
  moped_test <- 
    testing(split)
  
  # storing new vtreat plan
  treatplan <- designTreatmentsZ(moped_train, colnames(moped_train), minFraction = 1/10) 
  
  # inspecting results
  View(treatplan[["scoreFrame"]])
  
  # executing treatment
  train_treated <-  
    prepare(treatplan, moped_train) |>
    select(-model_catP)
  
  test_treated <- 
    prepare(treatplan, moped_test)  |>
    select(-model_catP)
  
  # log reg
  # model definition/training
  logreg_model_2 <- 
    glm(owned ~ ., data = train_treated, family = "binomial")
  
  logreg_model_2
  
  # summary of model
  summary(logreg_model_2)
  
  # test model
  test_treated$pred <- 
    predict(logreg_model_2, test_treated, type = "response")
  
  # saving this dataframe for later
  logreg_pred_2 <- 
    test_treated
  
  # xgboost
  # defining dataframes sans outcome
  xgb_train <- 
    train_treated |>
    select(-owned) |>
    as.matrix()
  
  xgb_test <- 
    test_treated |>
    select(-c(pred, owned)) |>
    as.matrix()
  
  # generating appropriate matrices
  xgbDM_train <- 
    xgb.DMatrix(data = xgb_train, label = train_treated$owned)
  
  xgbDM_test <- 
    xgb.DMatrix(data = xgb_test, label = test_treated$owned)
  
  # running cross validation to find the ideal parameters
  cv <- xgb.cv(data = xgbDM_train,
               nrounds = 100,
               nfold = 5,
               objective = "binary:logistic",
               max_depth = 5,
               early_stopping_rounds = 5, 
               verbose = FALSE   # silent
  )
  # fetching evaluation log
  cv$evaluation_log |>
    summarize(ntrees.train = which.min(train_logloss_mean),
              ntrees.test = which.min(test_logloss_mean))
  
  # checking cross validation results using xgb.train()
  # generating watchlist
  watchlist <- 
    list(train = xgbDM_train, test = xgbDM_test)
  
  # running xgb.train() 
  xgb_training <- 
    xgb.train(
      data = xgbDM_train,
      max.depth = 5, 
      objective = "binary:logistic",
      watchlist = watchlist, 
      nrounds = 100,
      verbose = 0
    )
  
  # obtaining evaluation log
  xgb_training$evaluation_log |>
    summarize(ntrees.train = which.min(train_logloss),
              ntrees.test = which.min(test_logloss))
  
  # defining final model
  xgb_model_2 <- xgboost(data = xgbDM_train, 
                               objective = "binary:logistic",
                               max.depth = 5, 
                               nrounds = 14, 
                               verbose = FALSE
  )
  
  # predictions 
  test_treated$pred <- 
    predict(xgb_model_2, xgb_test, nrounds = 9)
  
  # saving for evaluation
  xgb_pred_2 <- 
    test_treated
  
  # saving colnames for evaluation
  colnames_2 <- 
    colnames(xgb_train)

# models without `model`
#####
# models without `model`
  # test/train split
  split <-
    moped |>
    select(-model) |>
    initial_split(prop = 0.8)
  
  moped_train <- 
    training(split)
  
  moped_test <- 
    testing(split)
  
  # storing new vtreat plan
  treatplan <- designTreatmentsZ(moped_train, colnames(moped_train), minFraction = 1/10) 
  
  # inspecting results
  View(treatplan[["scoreFrame"]])
  
  # executing treatment
  train_treated <-  
    prepare(treatplan, moped_train)
  
  test_treated <- 
    prepare(treatplan, moped_test)
  
# log reg
  # model definition/training
  logreg_model_3 <- 
    glm(owned ~ ., data = train_treated, family = "binomial")
  
  logreg_model_3
  
  # summary of model
  summary(logreg_model_3)
  
  # test model
  test_treated$pred <- 
    predict(logreg_model_3, test_treated, type = "response")
  
  # saving this dataframe for evaluation
  logreg_pred_3 <- 
    test_treated
  
# xgboost
  # defining dataframes sans outcome
  xgb_train <- 
    train_treated |>
    select(-owned) |>
    as.matrix()
  
  xgb_test <- 
    test_treated |>
    select(-c(pred, owned)) |>
    as.matrix()
  
  # generating appropriate matrices
  xgbDM_train <- 
    xgb.DMatrix(data = xgb_train, label = train_treated$owned)
  
  xgbDM_test <- 
    xgb.DMatrix(data = xgb_test, label = test_treated$owned)
  
  
  # running cross validation to find the ideal parameters
  cv <- xgb.cv(data = xgbDM_train, 
               nrounds = 100,
               nfold = 5,
               objective = "binary:logistic",
               max_depth = 5,
               early_stopping_rounds = 5, 
               verbose = FALSE   # silent
  )
  # fetching evaluation log
  cv$evaluation_log |>
    summarize(ntrees.train = which.min(train_logloss_mean),
              ntrees.test = which.min(test_logloss_mean))
  
  # checking cross validation results using xgb.train()
  # generating watchlist
  watchlist <- 
    list(train = xgbDM_train, test = xgbDM_test)
  
  # running xgb.train() 
  xgb_training <- 
    xgb.train(
      data = xgbDM_train,
      max.depth = 5, 
      objective = "binary:logistic",
      watchlist = watchlist, 
      nrounds = 100,
      verbose = 0
    )
  
  # obtaining evaluation log
  xgb_training$evaluation_log |>
    summarize(ntrees.train = which.min(train_logloss),
              ntrees.test = which.min(test_logloss))
  
  # defining final model
  xgb_model_3 <- xgboost(data = xgbDM_train, 
                             objective = "binary:logistic",
                             max.depth = 5, 
                             nrounds = 15, 
                             verbose = FALSE
  )
  
  # predictions 
  test_treated$pred <- 
    predict(xgb_model_3, xgb_test, nrounds = 10)
  
  # saving for evaluation
  xgb_pred_3 <- 
    test_treated
  
  # saving variable names for evaluation
  colnames_3 <- 
    colnames(xgb_train)
  
# model evaluation
#####
# model set 1 evaluation
# logreg evaluation
  # glance to get model stats
  (perf <- glance(logreg_model_1))
  
  # calculating pseudo-R-squared
  (pseudoR2 <- 1 - perf$deviance/perf$null.deviance)
  
  # gain curve plot
  GainCurvePlot(logreg_pred_1, xvar = "pred", "owned", "Logistic regression model for moped ownership")
  
  # ROC curve
  ROCPlot(logreg_pred_1, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Logistic regression model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
# xgb evaluation
  # gain curve plot
  GainCurvePlot(xgb_pred_1, xvar = "pred", "owned", "Xtreme Gradient Boosting model for moped ownership")
  
  # ROC curve #2
  ROCPlot(xgb_pred_1, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Xtreme Gradient Boosting model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
  # inspecting feature importance
  (importance_matrix <- 
      xgb.importance(feature_names = colnames_1, 
                     model = xgb_model_1))
  
  # visualizing feature importance
  xgb.plot.importance(importance_matrix[1:14,])
  
# model set 2 evaluation
#####
# model set 2 evaluation
  # logreg evaluation
  # glance to get model stats
  (perf <- glance(logreg_model_2))
  
  # calculating pseudo-R-squared
  (pseudoR2 <- 1 - perf$deviance/perf$null.deviance)
  
  # gain curve plot
  GainCurvePlot(logreg_pred_2, xvar = "pred", "owned", "Logistic regression model for moped ownership")
  
  # ROC curve
  ROCPlot(logreg_pred_2, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Logistic regression model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
  # xgb evaluation
  # gain curve plot
  GainCurvePlot(xgb_pred_2, xvar = "pred", "owned", "Xtreme Gradient Boosting model for moped ownership")
  
  # ROC curve #2
  ROCPlot(xgb_pred_2, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Xtreme Gradient Boosting model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
  # inspecting feature importance
  (importance_matrix <- 
      xgb.importance(feature_names = colnames_2, 
                     model = xgb_model_2))
  
  # visualizing feature importance
  xgb.plot.importance(importance_matrix[1:13,])
  
# model set 3 evaluation
#####
# model set 3 evaluation
  # logreg evaluation
  # glance to get model stats
  (perf <- glance(logreg_model_3))
  
  # calculating pseudo-R-squared
  (pseudoR2 <- 1 - perf$deviance/perf$null.deviance)
  
  # gain curve plot
  GainCurvePlot(logreg_pred_3, xvar = "pred", "owned", "Logistic regression model for moped ownership")
  
  # ROC curve
  ROCPlot(logreg_pred_3, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Logistic regression model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
  # xgb evaluation
  # gain curve plot
  GainCurvePlot(xgb_pred_3, xvar = "pred", "owned", "Xtreme Gradient Boosting model for moped ownership")
  
  # ROC curve #2
  ROCPlot(xgb_pred_3, 
          xvar = "pred", 
          truthVar = "owned", 
          truthTarget = TRUE,
          title = "Xtreme Gradient Boosting model for moped ownership", 
          add_beta_ideal_curve = TRUE)
  
  # inspecting feature importance
  (importance_matrix <- 
      xgb.importance(feature_names = colnames_3, 
                     model = xgb_model_3))
  
  # visualizing feature importance
  xgb.plot.importance(importance_matrix[1:11,])
  