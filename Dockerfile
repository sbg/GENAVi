FROM rocker/shiny-verse:3.6.3

MAINTAINER Christian Frech "christian.frech@sbgenomics.com"

# Install dependencies and Download and install shiny server
RUN apt-get update && apt-get install -y \
    git libtiff-dev libjpeg-dev && \
    R -e "install.packages(c('BiocManager'), repos='https://cran.rstudio.com/')"

RUN R -e "BiocManager::install(c('shinyjs', 'plotly', 'shinythemes', 'shinyBS', 'shinycssloaders', 'prettydoc', 'shinyjqui', 'shinydashboard', 'shinyWidgets'))"
RUN R -e "BiocManager::install(c('DT', 'TTR', 'rlist', 'zoo', 'xts', 'quantmod', 'highcharter'))"
RUN R -e "BiocManager::install(c('tidyr', 'ggplot2', 'readr', 'magrittr', 'DESeq2', 'edgeR', 'iheatmapr', 'apeglm', 'ashr', 'msigdbr', 'DOSE', 'org.Hs.eg.db', 'clusterProfiler', 'enrichplot', 'GSEABase'))" \
RUN R -e "BiocManager::install('devtools')" \
RUN R -e "devtools::install_github('yang-tang/shinyjqui')" && \
    cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/ && \
    rm -rf /var/lib/apt/lists/*

RUN R -e "BiocManager::install('sevenbridges')"
RUN apt-get update && apt-get install -y curl

#can't do this b/c of VPN; has to wait until we have it on github
#RUN git clone https://gitlab.sbgenomics.com/gioia/genavi.git /srv/shiny-server/ && \
#	mkdir /var/log/shiny-server/genavi_log && chown shiny:shiny /var/log/shiny-server/genavi_log

ADD . /srv/shiny-server/
ADD shiny-server.sh /usr/bin/shiny-server.sh
ADD shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN mkdir /var/log/shiny-server/genavi_log && chown shiny:shiny /var/log/shiny-server/genavi_log

EXPOSE 3838

CMD ["/usr/bin/shiny-server.sh"]