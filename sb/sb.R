## ---------------------------
## Implements OAuth2 client to authenticate app against SB platform.
## If authentication is successful, access to SB Public API is provided
## via global 'sb_api()' function. The UI wrapper function in here
## is called upon every page reload to make sure auth is valid. If not,
## it automatically prompts user to authenticate again before returning
## control to the original UI.
##
## Copyright (c) 2020 Seven Bridges Genomics
## ---------------------------

library("httr")
library("yaml")
library("sevenbridges")

# create OAuth endpoint and app using information in sb.yml

message("Running as user: ", system("whoami", intern = T))

sb_config <<- yaml.load_file("sb/sb.yml")

redirect_url <- Sys.getenv("SB_REDIRECT_URL")
if (is.na(redirect_url) || is.null(redirect_url) || redirect_url == "") {
  redirect_url <- sb_config$app$url
}
message("Redirect URL: ", redirect_url)

client_id <- Sys.getenv("SB_CLIENT_ID")
if (is.na(client_id) || is.null(client_id) || client_id == "") {
  client_id <- sb_config$app$id
}
message("CLIENT ID: ", client_id)

client_secret <- Sys.getenv("SB_CLIENT_SECRET")
if (is.na(client_secret) || is.null(client_secret) || client_secret == "") {
  client_secret <- sb_config$app$secret
}

app <- httr::oauth_app(
  appname = sb_config$app$name,
  key = client_id,
  secret = client_secret,
  redirect_uri = redirect_url
)

sb_oauth_endpoint <- oauth_endpoint(
  authorize = sb_config$endpoints$oauth2$authorization_url,
  access = sb_config$endpoints$oauth2$token_url,
  jwk = sb_config$endpoints$oauth2$jwks_url,
  logout = sb_config$endpoints$oauth2$logout_url
)

# empty HTML page redirecting to SB login page
redirect_html <- function(state) {
  url <- oauth2.0_authorize_url(sb_oauth_endpoint, app, scope = "openid", state=state)
  redirect <- sprintf("location.replace(\"%s\");", url)
  html <- tags$script(HTML(redirect))
  return(html)
}

# global holding SB context information after login,
# don't access context directly but user get_...() helper function below.
sb_contexts <<- list()

# wrapper around original Shiny ui to perform oauth redirection.
# if successful, initialized API object can be accessed through sb_api() 
# function throughout the application
sb_ui <- function(req) {

  query_string <- parseQueryString(req$QUERY_STRING)
  message("Query string: ", str(query_string))

  # if oauth code not part of URL, redirect to oauth endpoint to get one
  # hold on to provided project context by passing it as state information
  auth_code <- query_string$code
  if (is.null(auth_code)) {
    message("Requesting authentication code...")
    return(redirect_html(state=query_string$project))
  }

  context <- list()
  
  # hold on to current project id if part of oauth response
  project <- query_string$state
  if(!is.null(project)) {
    message("Project context: ", project)
    context$project <- project
  }

  # exchange authentication token for access token
  resp <- suppressMessages(try({
    token <- oauth2.0_token(
      app = app,
      endpoint = sb_oauth_endpoint,
      credentials = oauth2.0_access_token(
        sb_oauth_endpoint, 
        app,
        code = auth_code,
        use_basic_auth = TRUE
      ),
      cache = FALSE
    )
    
    # remember API access token
    context$access_token <- token$credentials$access_token
  }, silent = TRUE))
  
  # if we failed to get access token, attempt re-authentication
  if (class(resp) == "try-error") {
    warning(resp)
    message("Requesting authentication token...")
    return(redirect_html(state=project))
  }
  
  # init API with received access token and test it
  api_base_url <- sb_config$endpoints$api$base_url
  message("Initializing API endpoint: ", api_base_url)
  context$api <- sevenbridges::Auth(token = context$access_token, url = api_base_url, authorization = TRUE)
  user <- context$api$user()
  message("Successfully authenticated as: ", user$username)

  # hold on to initialized context for this app code
  sb_contexts[[query_string$code]] <<- context
  
  # return UI
  return(ui)
}

# call logout endpoint and invalidate access token. this function is called
# either if "Logout" button is pressed within the application
sb_logout <- function() {
  message("Logging out...")
  isolate({
    resp <- httr::DELETE(sb_config$endpoints$oauth2$logout_url, add_headers(Authorization = paste("Bearer", get_access_token(), sep = " ")))
    sb_contexts[[getQueryString()$code]] <<- NULL
  })
  return(resp)
}


## ----
# additional SB helper function down this line
## ----

sb_api <- function() {
  sb_contexts[[getQueryString()$code]]$api
}

get_access_token <- function() {
  sb_contexts[[getQueryString()$code]]$access_token
}

get_user_info <- function() {
  user_info_url <- sb_config$endpoints$oauth2$user_info_url
  resp <- httr::GET(user_info_url, add_headers(Authorization = paste("Bearer", get_access_token(), sep = " ")))
  httr::content(resp)
}

get_jwk <- function() {
  jwks_url <- sb_config$endpoints$oauth2$jwks_url
  resp <- httr::GET(jwks_url, add_headers(Authorization = paste("Bearer", get_access_token(), sep = " ")))
  httr::content(resp)
}

get_project_context <- function() {
  sb_contexts[[getQueryString()$code]]$project
}

get_projects <- function() {
  p <- try(sb_api()$project(complete = TRUE), silent = TRUE)

  if (class(p) == "try-error") return(NULL)
  if (class(p) == "Project") p <- list(p)

  project_list <- sapply(p, "[[", "id")
  names(project_list) <- sapply(p, "[[", "name")
  return(as.list(project_list))
}
