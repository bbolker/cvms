# Internal linear regression evaluation
linear_regression_eval <- function(data,
                                   models,
                                   predictions_col = "predictions",
                                   targets_col = "targets",
                                   id_col = NULL,
                                   id_method = NULL,
                                   fold_info_cols = list(rel_fold = "rel_fold",
                                                         abs_fold = "abs_fold",
                                                         fold_column = "fold_column"),
                                   model_specifics = list(),
                                   metrics,
                                   include_fold_columns = TRUE,
                                   include_predictions = TRUE,
                                   na.rm = TRUE){

  REML <- tryCatch({
    model_specifics[["REML"]]
    }, error = function(e){
      stop("model_specifics must contain the REML argument.")
    })

  num_folds <- length(unique(data[[ fold_info_cols[["abs_fold"]] ]]))

  fold_and_fold_col <- create_fold_and_fold_column_map(data, fold_info_cols)

  # Check if any models were passed
  if (is.null(models)) {
    models_was_null <- TRUE
    models <- list(NULL)
  } else {
    models_was_null <- FALSE
  }

  # When adding NULL to a not-named list, it isn't actually added
  # so if a model object is NULL (didn't converge),
  # the list will be shorter than the number of folds
  # If the list is named, it may contain NULLs. Therefore we count these.

  if(isTRUE(models_was_null) ||
     (length(models) == num_folds && count_nulls_in_list(models) == 0)){

    if (isTRUE(include_predictions)){

      # Nest predictions and targets
      predictions_nested <- nesting_predictions_gaussian(
        data = data,
        predictions_col = predictions_col,
        targets_col = targets_col,
        id_col = id_col,
        id_method = id_method,
        fold_info_cols = fold_info_cols,
        include_fold_columns = include_fold_columns)

    } else {
      predictions_nested <- NULL
    }

    # if ("RMSE" %in% metrics || "MAE" %in% metrics){ # TODO Refactor to avoid computing metrics the user doesn't want

    # Calculate RMSE and MAE
    rmse_mae_per_fold <- data %>%
      dplyr::group_by(!! as.name(fold_info_cols[["fold_column"]]),
                      !! as.name(fold_info_cols[["rel_fold"]])) %>%
      dplyr::summarize(RMSE = calculate_RMSE(!! as.name(predictions_col),
                                             !! as.name(targets_col)),
                       MAE = calculate_MAE(!! as.name(predictions_col),
                                           !! as.name(targets_col)))

    # Add abs_fold. By doing it this way, we get better column sorting
    rmse_mae_per_fold <- fold_and_fold_col %>%
      dplyr::left_join(rmse_mae_per_fold,
                      by = c(fold_info_cols[["fold_column"]],
                             fold_info_cols[["rel_fold"]]))

    # Average RMSE
    # First average per fold column, then average those
    avg_rmse_mae <- rmse_mae_per_fold %>%
      dplyr::group_by(!! as.name(fold_info_cols[["fold_column"]])) %>%
      dplyr::summarize(RMSE = mean(.data$RMSE, na.rm = na.rm),
                       MAE = mean(.data$MAE, na.rm = na.rm)) %>%
      dplyr::summarize(RMSE = mean(.data$RMSE, na.rm = na.rm),
                       MAE = mean(.data$MAE, na.rm = na.rm))

    # Get model metrics
    model_metrics_per_fold <- plyr::ldply(models, function(m){
      fold_eval <- linear_regression_model_eval(m, REML)
      # Deselect disabled metrics
      fold_eval %>%
        dplyr::select(dplyr::one_of(intersect(metrics, colnames(fold_eval))))
    }) %>%
      mutate(abs_fold = 1:dplyr::n()) %>%
      dplyr::inner_join(fold_and_fold_col,
                        by = c("abs_fold" = fold_info_cols[["abs_fold"]]))

    # Average model metrics
    # First average per fold column, then average those
    avg_model_metrics <- model_metrics_per_fold %>%
      dplyr::select(-c(.data$abs_fold,
                       !! as.name(fold_info_cols[["rel_fold"]]))) %>%
      dplyr::group_by(!! as.name(fold_info_cols[["fold_column"]])) %>%
      dplyr::summarise_all(.funs = list(~mean(., na.rm = na.rm))) %>%
      dplyr::select(-c(!! as.name(fold_info_cols[["fold_column"]]))) %>%
      dplyr::summarise_all(.funs = list(~mean(., na.rm = na.rm)))

    if (!isTRUE(models_was_null)){
      # Get model coefficients
      nested_coefficients <- tryCatch({
        get_nested_model_coefficients(models, fold_info = list(
          folds = fold_and_fold_col[["rel_fold"]],
          fold_columns = fold_and_fold_col[["fold_column"]]),
          include_fold_columns = include_fold_columns)
      }, error = function(e){

        get_nested_model_coefficients(
          NULL, include_fold_columns = include_fold_columns)
      })
    } else {
      nested_coefficients <- NULL
    }

  } else {

    # Create NA results
    # TODO Make some comments and make it a bit prettier ;)

    rmse_mae_per_fold <- tibble::tibble("RMSE" = rep(NA, num_folds))
    rmse_mae_per_fold[[fold_info_cols[["fold_column"]]]] <- fold_and_fold_col[[fold_info_cols[["fold_column"]]]]
    rmse_mae_per_fold[[fold_info_cols[["abs_fold"]]]] <- fold_and_fold_col[[fold_info_cols[["abs_fold"]]]]
    rmse_mae_per_fold[[fold_info_cols[["rel_fold"]]]] <- fold_and_fold_col[[fold_info_cols[["rel_fold"]]]]
    rmse_mae_per_fold <- rmse_mae_per_fold %>%
      dplyr::select(-.data$RMSE, dplyr::everything()) # Move RMSE to the end (weird syntax)
    avg_rmse_mae <- tibble::tibble("RMSE" = NA, "MAE" = NA)
    model_metrics_per_fold <- list(linear_regression_model_eval(NULL, NULL)) %>%
      rep(num_folds) %>%
      dplyr::bind_rows()
    model_metrics_per_fold[[fold_info_cols[["fold_column"]]]] <- fold_and_fold_col[[fold_info_cols[["fold_column"]]]]
    model_metrics_per_fold[["abs_fold"]] <- fold_and_fold_col[[fold_info_cols[["abs_fold"]]]]
    model_metrics_per_fold[[fold_info_cols[["rel_fold"]]]] <- fold_and_fold_col[[fold_info_cols[["rel_fold"]]]]
    avg_model_metrics <- linear_regression_model_eval(NULL, FALSE)

    if (!isTRUE(models_was_null)){
      nested_coefficients <- get_nested_model_coefficients(NULL)
    } else {
      nested_coefficients <- NULL
    }
    if (isTRUE(include_predictions)){
      predictions_nested <- NA
    } else {
      predictions_nested <- NULL
    }

  }

  # Combine
  avg_results <- avg_rmse_mae %>%
    dplyr::bind_cols(avg_model_metrics)
  avg_results <- avg_results %>%
    dplyr::select(dplyr::one_of(intersect(metrics, colnames(avg_results))))

  results_per_fold <- rmse_mae_per_fold %>%
    dplyr::full_join(model_metrics_per_fold,
                     by = c(fold_info_cols[["fold_column"]],
                            "abs_fold" = fold_info_cols[["abs_fold"]],
                            fold_info_cols[["rel_fold"]])) %>%
    dplyr::rename(`Fold Column` = fold_info_cols[["fold_column"]],
                  Fold = fold_info_cols[["rel_fold"]]) %>%
    dplyr::select(-.data$abs_fold)

  results_per_fold <- results_per_fold %>%
    dplyr::select(dplyr::one_of(c(
      "Fold Column", "Fold",
      intersect(metrics, colnames(results_per_fold)))))

  if (!is.null(predictions_nested)){
    if (!is.na(predictions_nested)){
      avg_results[["Predictions"]] <- predictions_nested$predictions
    } else {
      avg_results[["Predictions"]] <- NA
    }
  }

  # nest fold results and add to result tibble
  avg_results[["Results"]] <- nest_results(results_per_fold)[["results"]]

  # Add nested coefficients
  avg_results[["Coefficients"]] <- nested_coefficients

  return(avg_results)

}


linear_regression_model_eval <- function(model, REML){

  if (is.null(model)){
    r2m_ <- NA
    r2c_ <- NA
    AIC_ <- NA
    AICc_ <- NA
    BIC_ <- NA
  } else {
    r2m_ <- calculate_r2m(model)
    r2c_ <- calculate_r2c(model)
    AIC_ <- calculate_AIC(model)
    AICc_ <- calculate_AICc(model, REML)
    BIC_ <- calculate_BIC(model)
  }

  tibble::tibble('r2m' = r2m_, 'r2c' = r2c_,
                 'AIC' = AIC_, 'AICc' = AICc_,
                 'BIC' = BIC_)
}

# Try to retrieve
# fold_info contains the fold and fold column for each model
get_nested_model_coefficients <- function(models, fold_info=list(folds = NULL,
                                                                 fold_columns = ".folds"),
                                          include_fold_columns = TRUE){
  # Note: models should be ordered by the fold they were fitted in

  if (is.null(models)){

    NA_coeffs <- tibble::tibble(
      'term' = NA,
      'estimate' = NA,
      'std.error' = NA,
      'statistic' = NA,
      'Fold' = NA,
      "Fold Column" = NA
    )

    if (!isTRUE(include_fold_columns)){
      NA_coeffs <- NA_coeffs %>%
        dplyr::select(-dplyr::one_of("Fold", "Fold Column"))
    }

    nested_NA_coeffs <- NA_coeffs %>%
      nest_models() %>%
      dplyr::pull(.data$Coefficients)

    return(nested_NA_coeffs)

  }

  if (is.null(fold_info[["folds"]])){
    folds <- seq_len(length(models))
    fold_columns <- rep(fold_info[["fold_columns"]], length(models))
  } else {
    folds <- fold_info[["folds"]]
    fold_columns <- fold_info[["fold_columns"]]
  }

  tryCatch({

    coefs_tidy <- plyr::llply(seq_len(length(models)), function(i){

      tryCatch({
        broom::tidy(models[[i]], effects = c("fixed"))
      }, error = function(e){

        # If broom::tidy wasn't implemented for the model type
        # let's grab the coefficients manually if possible

        if (grepl("Error: No tidy method for objects of class",
                  as.character(e), ignore.case = TRUE) ||

            # Multinom requires training data in tidy()
            # This doesn't work anyway right now though
            # TODO? We would probably have to call tidy() in
            # a different environment with the training data
            # but that would require a major rewrite
            grepl("object 'train_data' not found",
                   as.character(e), ignore.case = TRUE)){

          # Try to extract coefficients
          coefs <- tryCatch({stats::coef(models[[i]])},
                            error = function(e){return(NA)})

          # If successful, manually create tidy tibble
          if ((length(coefs) == 1 && !is.na(coefs)) ||
              length(coefs) > 1){
            terms <- names(coefs)
            return(tibble::tibble(term = terms, estimate = coefs))

            # Else, return default NA coefficient tibble
          } else {
            return(get_nested_model_coefficients(
              NULL, include_fold_columns = include_fold_columns))
          }

        } else {

          warning(e)
          # Return default NA coefficient tibble
          return(get_nested_model_coefficients(
            NULL, include_fold_columns = include_fold_columns))
        }

      }) %>%
        dplyr::mutate(Fold = folds[[i]],
                      `Fold Column` = fold_columns[[i]])
    }) %>%
      dplyr::bind_rows()

    if (!isTRUE(include_fold_columns)){
      coefs_tidy <- coefs_tidy %>%
        dplyr::select(-dplyr::one_of("Fold", "Fold Column"))
    }

    coefs_tidy %>%
      nest_models() %>%
      dplyr::pull(.data$Coefficients)

  }, error = function(e){
    stop(paste0("Error when extracting model coefficients: ", e))
  })

}
