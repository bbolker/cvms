# R CMD check NOTE handling
if(getRversion() >= "2.15.1")  utils::globalVariables(c("."))

#' @importFrom dplyr %>%
validate_fn_single <- function(train_data,
                              model_fn,
                              evaluation_type = "gaussian",
                              model_specifics = list(),
                              model_specifics_update_fn = NULL,
                              test_data = NULL,
                              partitions_col = '.partitions',
                              metrics = list(),
                              err_nc = FALSE) {

  # Set errors if input variables aren't what we expect / can handle
  # TODO WORK ON THIS SECTION!
  stopifnot(
    is.data.frame(train_data),
    is.data.frame(test_data) || is.null(test_data))

  if (is.null(test_data)) {
    stopifnot(is.factor(train_data[[partitions_col]]))
  }

  # Check arguments
  # Check model_specifics arguments
  if (!is.null(model_specifics_update_fn)){
    model_specifics <- model_specifics_update_fn(model_specifics)
  }

  if (evaluation_type %ni% c("gaussian", "binomial")){
    stop("'evaluation_type' must be either 'gaussian' or 'binomial'.")
  }

  # If train and test data is not already split,
  # get train and test set
  if (is.null(test_data)) {
    # Create test set
    test_data <- train_data[train_data[[partitions_col]] == 2,]
    # Create training set
    train_data <- train_data[train_data[[partitions_col]] == 1,]
  }

  # Remove partitions column to allow for "y ~ ." definitions in the model formula
  train_data[[partitions_col]] <- NULL
  test_data[[partitions_col]] <- NULL

  # Train and test the model

  fitting_output <- model_fn(train_data = train_data,
                             test_data = test_data,
                             fold_info = list(rel_fold = 1, abs_fold = 1, fold_column = 1), # we'll remove this later
                             model_specifics = model_specifics)

  predictions_and_targets <- fitting_output[["predictions_and_targets"]]

  # Extract models
  model <- fitting_output[["model"]]

  # Extract singular fit message
  threw_singular_fit_message <- fitting_output[["threw_singular_fit_message"]]

  model_evaluation <- internal_evaluate(
    predictions_and_targets,
    type = evaluation_type,
    predictions_col = "prediction",
    targets_col = "target",
    fold_info_cols = list(
      rel_fold = "rel_fold",
      abs_fold = "abs_fold",
      fold_column = "fold_column"
    ),
    models = list(model),
    model_specifics = model_specifics,
    metrics = metrics
  ) %>%
    dplyr::mutate(`Convergence Warnings` = ifelse(is.null(model), 1, 0),
                  `Singular Fit Messages` = ifelse(isTRUE(threw_singular_fit_message), 1, 0))


  # Remove Results tibble if linear regression
  if (evaluation_type == "gaussian"){
    model_evaluation <- model_evaluation %>%
    dplyr::select(-dplyr::one_of("Results"))
  }

  if (isTRUE(err_nc) && model_evaluation[["Convergence Warnings"]] != 0) {
    stop("Model did not converge.")
  }

  return(list("Results" = model_evaluation, "Model" = model))

}
