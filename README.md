**GENAVi** (Gene Expression Normalization Analysis and Visualization) is an rshiny web application that provides a GUI based platform for the analysis of gene expression data. 

GENAVi combines several R packages commonly used for normalizing, clustering, visualizing, and performing differential expression analysis (DEA) on RNA-seq data.

Within our application we have also included an RNA-seq data set on a panel of 20 cell lines commonly used for the study of breast and ovarian cancer.
This dataset can serve as an introduction to the various functions of GENAVi.
In addition to being able to query and analyze the dataset we provided, users can also upload their own gene expression count matrix and apply all of the functions within GENAVi to analyze their own data.

GENAVi is hosted on the junkdnalab rshiny server which can be accessed in any browser with internet connection through this link: https://junkdnalab.shinyapps.io/GENAVi/

Additionally, GENAVi can be run on a users local machine or server by entering the command: shiny::runGitHub("alpreyes/GENAVi") in an RStudio window. 
With this method, all necessary R packages will be automatically installed, all source code used to build GENAVi will be downloaded directly from the GitHub repository, and the application will be hosted and run locally.

Lastly, the user can also run GENAVi on a local machine or server via a docker image through this link: https://hub.docker.com/r/cedarscompbio/genavi/

We recommend running GENAVi on a local machine or server when uploading a large dataset that would require a more powerful server than the junkdnalab rshiny server for analysis.

# Seven Bridges modifications

## Authentication and authorization using OAuth2

To allow GENAVi direct access to a user's files stored on the Seven Bridges Platform, an OAuth2 authentication flow was built into the Shiny app. This is possible because the Seven Bridges Platform can serve as Authorization and Resource Server under the OAuth2 protocol.

GENAVi users first log into the app using their Seven Bridges Platform credentials. If successful, the app is handed over a **temporary access token**. GENAVi then uses this access token to authenticate against the Seven Bridges Public API and to access the platform on the user's behalf.  

If a user is already logged into the Seven Bridges Platform, a re-login is not required. However, GENAVi users are always required to consent to a **user disclaimer**, which explains risks that are associated with handing over an *unscoped* API access token to an external app, even if it is just temporary. If the disclaimer is not accepted, the user is redirected to the main Seven Bridges Platform page and no access token is provided to the app.

The following changes were introduced into the stock GENAVi app to support OAuth2-based authentication and authorization. The goal was to make the necessary changes minimally invasive. You can follow the same steps to add authentication to your own Shiny app, or implement any other method supporting OAuth2, for example using an OAuth2 reverse proxy in front of your application (https://oauth2-proxy.github.io/oauth2-proxy/).

* `app.R`: This file was added as new app entrypoint. Its purpose is to not load the original Shiny UI object of the app but a **wrapper UI function** that performs OAuth2 authentication on every page reload. Only if authentication is successful, the original `ui` object of the Shiny app is returned. This mechanism allows the rest of the application code to remain entirely ignorant of authentication-related changes.
* `sb/sb.R`: Contains the function definition of the wrapper UI that performs the OAuth2 dance. In addition, it defines several functions that provide access to platform information after successful authentication, most importantly the **initialized API object** and the current platform project from within which the Shiny app was started (**project context**). It should not be necessary to modify any content of this file for your own Shiny apps.
* `sb/sb.yml`: Configuration file describing all Seven Bridges OAuth2 endpoints and application details (name, id, secret, redirect URL). Application information needs to match those registered with the Seven Bridges Platform, otherwise authentication will fail. IMPORTANT: Client ID and client secret stored in this file are not supposed to become part of a shared code repository and should only be used as part of a private development environment. The proper way to provide client ID and secret in a shared hosting environment is using environment variables `SB_CLIENT_ID` and `SB_CLIENT_SECRET` instead, which take priority over values specified in `sb.yml`.

## Functional changes

We added a few features to the stock GENAVi app to take advantage of platform integration and to improve user flow.

First, files with RNA-seq count data can now be loaded directly from a platform project. The count matrix is then computed on-the-fly from those files. This supplements the already existing functionality to upload a count matrix directly from a user's local computer. Towards that end, we added a **new application tab "Project files"**, on which users first select one of their Seven Bridges projects and then select files containing count data within that project. Files can be filtered and sorted by name, type, size, or file metadata. 

The new tab has been added directly to the `fluidPage` defined inside `ui/ui.R`. Note that when the GENAVi app is launched from within a Seven Bridges project, the current project is already pre-selected and files inside that project are already shown, which simplifies the user flow further.

Regarding metadata, sample ID, case ID, and sample type are automatically parsed from file metadata and made available to the GENAVi app at various points, most importantly when selecting input files and when selecting samples and model during differential gene expression analysis.

Finally, a **"Logout" button** was added at the top-right corner of the app. A logout button is *required* for any web app connected to the SB platform to allow users to revoke granted platform access at any point and invalidate all issued auth tokens.

All server-side changes were made in the file `server/server.R`. 

## Deployment

We modified the `Dockerfile` for building a docker container with the Seven Bridges version of the GENAVi app inside. 

The resulting docker image was also pushed to the Seven Bridges docker repository and is available under `images.sbgenomics.com/external-demos/genavi`.


# Run GENAVi (Seven Bridges modified version)

To learn how to spin up a hosting environment to run GENAVi for demo purposes, either locally or from a vayu, please refer to our internal documentation available here: https://sbgdev.atlassian.net/wiki/spaces/PROD/pages/2783707466/Hosting+the+GENAVi+custom+frontend

For other hosting environments, you can run the dockerized version of GENAVi with the following `docker run` command, making sure to replace `<...>` with values corresponding to your specific environment:

```
docker run -d --restart unless-stopped -u 999 -p <port>:3838 \
  -e SB_CLIENT_ID=<your-client-id> \
  -e SB_CLIENT_SECRET=<your-client-secret> \
  -e SB_REDIRECT_URL=<your-redirect-url> \
  <your-docker-image-id>
```

## Authentication failures

Authentication failures resulting in the dreaded browser "deer page" typically have one of the following causes:
* Application information provided inside `sb.yml` or via environment variables does not match exactly the application information registered on the Seven Bridges Platform.
* Your user account does not have the permission to log into that application. Each web application defines its own members with permissions, and only members with EXECUTE permission are allowed to log in. Please contact Seven Bridge support to change membership permissions.
* Your user account is associated with more than one division, and your default division (the one you see after platform login) differs from the division under which the app is registered. This is a known limitation until a division context switcher becomes available.
* Your user account has elevated privileges (staff or superuser). For security reasons, only regular user accounts are allowed to log into a web application that authenticates via OAuth2.
* Your user account has access to controlled-access data, but the application you log into has not been licensed by Seven Bridges to handle controlled-access data.

Please get in touch with Seven Bridges Support to help resolving any of these authentication problems.