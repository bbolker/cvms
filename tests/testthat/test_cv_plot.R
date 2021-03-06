library(cvms)
context("cv_plot()")


test_that("cv_plot() works",{

  # Load data and fold it
  set_seed_for_R_compatibility(1)
  dat <- groupdata2::fold(participant.scores, k = 4,
                          cat_col = 'diagnosis',
                          id_col = 'participant')

  # Cross-validate the data
  CVbinom <- cross_validate(dat, "diagnosis~score",
                            fold_cols = '.folds',
                            family='binomial', REML = FALSE,
                            model_verbose=FALSE)

  CVgauss <- cross_validate(dat, "score~diagnosis",
                            fold_cols = '.folds',
                            family='gaussian', REML = FALSE,
                            model_verbose=FALSE)

  # If anyone can suggest a good way to test ggplot objects, feel free!
  expect_is(cv_plot(CVbinom, type = 'ROC'), 'ggplot')
  expect_is(cv_plot(CVgauss, type = 'RMSE'), 'ggplot')
  expect_is(cv_plot(CVgauss, type = 'r2'), 'ggplot')
  expect_is(cv_plot(CVgauss, type = 'IC'), 'ggplot')
  expect_is(cv_plot(CVgauss, type = 'coefficients'), 'ggplot')

})

