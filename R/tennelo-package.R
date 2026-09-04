#' @keywords internal
"_PACKAGE"

# .data is how the ggplot2 code refers to columns of the data being plotted
# without creating an undeclared global. Importing it from rlang is what makes
# that explicit to R CMD check.
#' @importFrom rlang .data
NULL
