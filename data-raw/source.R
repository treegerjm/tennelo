# Shared configuration and provenance helpers for the download scripts.
#
# The upstream repository JeffSackmann/tennis_atp went offline during 2026,
# together with tennis_wta and the point-by-point repositories. The data is
# taken from an archival mirror instead. See DATA-SOURCES.md.

SOURCE <- list(
  name       = "Aneeshers/tennis-sackmann-archive",
  base_url   = "https://raw.githubusercontent.com/Aneeshers/tennis-sackmann-archive/main/atp",
  api_url    = "https://api.github.com/repos/Aneeshers/tennis-sackmann-archive/commits/main",
  upstream   = "https://github.com/JeffSackmann/tennis_atp (offline as of 2026)",
  compiler   = "Jeff Sackmann",
  licence    = "CC BY-NC-SA 4.0",
  attribution = "Match and ranking data compiled by Jeff Sackmann."
)

announce_source <- function() {
  cat("\n")
  cat("  Source      : ", SOURCE$name, "\n", sep = "")
  cat("  Compiled by : ", SOURCE$compiler, "\n", sep = "")
  cat("  Upstream    : ", SOURCE$upstream, "\n", sep = "")
  cat("  Licence     : ", SOURCE$licence, "\n", sep = "")
  cat("\n")
  cat("  This data is licensed for non-commercial use and requires attribution.\n")
  cat("  You are responsible for complying with that licence. Nothing downloaded\n")
  cat("  here is redistributed by this package.\n\n")
}

source_commit <- function() {
  out <- tryCatch({
    con <- url(SOURCE$api_url, open = "rb")
    on.exit(close(con), add = TRUE)
    txt <- paste(readLines(con, warn = FALSE), collapse = "")
    m <- regmatches(txt, regexpr('"sha"[[:space:]]*:[[:space:]]*"[0-9a-f]{40}"', txt))
    # Pull the hash out of the matched key/value pair. A greedy sub() on the
    # quote character would strip past the closing quote and return "".
    if (length(m) == 0L) NA_character_ else regmatches(m, regexpr("[0-9a-f]{40}", m))
  }, error = function(e) NA_character_)
  out
}

sha256 <- function(path) {
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(file = path, algo = "sha256"))
  }
  # No extra dependency required: shasum ships with macOS and Linux.
  out <- tryCatch(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE),
                  error = function(e) NA_character_)
  if (length(out) == 0L || is.na(out[1])) NA_character_ else sub(" .*$", "", out[1])
}

download_one <- function(remote, local, overwrite = FALSE) {
  if (file.exists(local) && !overwrite) {
    return(list(file = basename(local), status = "kept"))
  }
  url <- file.path(SOURCE$base_url, remote)
  ok <- tryCatch({
    utils::download.file(url, local, quiet = TRUE, mode = "wb"); TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok || !file.exists(local)) {
    stop("Download failed: ", url, call. = FALSE)
  }
  list(file = basename(local), status = "downloaded")
}

# The manifest is what makes a published analysis reproducible: it records
# exactly which bytes were used. It stays out of git along with the data.
write_manifest <- function(dir, files, commit, kind) {
  info <- file.info(files)
  manifest <- data.frame(
    file        = basename(files),
    url         = file.path(SOURCE$base_url, kind, basename(files)),
    bytes       = info$size,
    sha256      = vapply(files, sha256, character(1)),
    retrieved   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    source      = SOURCE$name,
    source_commit = commit,
    licence     = SOURCE$licence,
    stringsAsFactors = FALSE
  )
  path <- file.path(dir, "MANIFEST.csv")
  utils::write.csv(manifest, path, row.names = FALSE)
  cat("  manifest    : ", path, " (", nrow(manifest), " files)\n", sep = "")
  invisible(manifest)
}

verify_columns <- function(path, required, label) {
  head_row <- utils::read.csv(path, nrows = 1, stringsAsFactors = FALSE,
                              colClasses = "character")
  missing <- setdiff(required, names(head_row))
  if (length(missing) > 0L) {
    stop("Source schema changed: ", label, " is missing ",
         paste(missing, collapse = ", "),
         ".\nThe download stopped rather than write data the package cannot read.",
         call. = FALSE)
  }
  invisible(TRUE)
}
