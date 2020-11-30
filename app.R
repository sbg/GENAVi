library("shiny")

# source original ui and server objects

source("ui/ui.R", local = TRUE)
source("server/server.R", local = TRUE)

# add SB oauth2; 'sb_ui' is wrapper around original 'ui' object;
# ensures proper initialization of SB API, which can be accessed using
#   get_api() function throughout the application

source("sb/sb.R", local = TRUE)

shinyApp(sb_ui, server, options=list(port=3838))
