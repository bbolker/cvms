basics_fit_model <- function(model_specifics, train_set){

  # Extract arguments from model_specifics
  model_formula <- model_specifics[["model_formula"]]
  model_type <- model_specifics[["model_type"]]
  family <- model_specifics[["family"]]
  link <- model_specifics[["link"]]
  control <- model_specifics[["control"]]
  REML <- model_specifics[["REML"]]
  model_verbose <- model_specifics[["model_verbose"]]

  # Checks the model_type and fits the model on the train_set
  if (model_type == 'lm'){

    if (model_verbose == TRUE){
      if (is.null(link) || link == 'identity'){
        message('Model function: Used lm()')
      } else {
        message('Model function: Used glm()')
      }
    }

    # Fit the model using lm() or glm() depending on link function
    # Return this model to model_temp
    if (is.null(link) || link == 'identity'){
      return(lm(model_formula,train_set))
    } else {
      return(glm(model_formula, train_set,
                 family = gaussian(link=link)))
    }

  } else if (model_type == 'lmer'){

    if (model_verbose == TRUE){
      if (is.null(link) || link == 'identity'){
        message('Model function: Used lme4::lmer()')
      } else {
        message('Model function: Used lme4::glmer()')
      }
    }

    # Fit the model using lmer() or glmer() depending on link function
    if (is.null(link) || link == 'identity'){
      return(lme4::lmer(model_formula, train_set, REML=REML, control=control))
    } else {
      return(lme4::glmer(model_formula, train_set,
                         family = gaussian(link=link),
                         control=control))
    }

  } else if (model_type == 'glm'){

    if (model_verbose == TRUE){
      message('Model function: Used glm()')}

    # Fit the model using glm()
    # Return this model to model_temp
    if (!is.null(link)){
      return(glm(model_formula, train_set, family = binomial(link=link)))
    } else {
      return(glm(model_formula, train_set, family = family))
    }

  } else if (model_type == 'glmer'){

    if (model_verbose == TRUE){
      message('Model function: Used lme4::glmer()')}

    # Fit the model using glmer()
    # Return this model to model_temp

    return(lme4::glmer(model_formula, train_set, family = binomial(link=link), control = control))

  }

}
