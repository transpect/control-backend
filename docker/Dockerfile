# Build the container from this directory:
# docker build -t svn-server .

## svn or apache on alpine have an authz bug, therefore using ubuntu
FROM adoptopenjdk/openjdk15:jre

RUN apt-get update
RUN apt-get install -y apache2 libapache2-mod-svn subversion emacs sudo git

# Content repositories: One for the imprint/series hierarchy, one parent path
# for the individual works:
RUN mkdir -p /data/svn/works /data/svn/hierarchy
COPY apache/repos/works.conf apache/repos/hierarchy.conf /etc/apache2/conf-available
RUN cd /etc/apache2/conf-enabled && ln -s ../conf-available/works.conf ../conf-available/hierarchy.conf .
COPY svn /etc/svn
RUN htpasswd -b /etc/svn/default.htpasswd testi popesti
RUN chmod -R o-rwx /etc/svn
RUN chown -R www-data.www-data /etc/svn

RUN svnadmin create /data/svn/works/testwork
RUN svnadmin create /data/svn/hierarchy

RUN cd /etc/apache2/mods-enabled && ln -s ../mods-available/proxy.load ../mods-available/proxy_http.load .
COPY apache/reverse-proxy.conf /etc/apache2/conf-available
COPY apache/ports.conf /etc/apache2
RUN cd /etc/apache2/conf-enabled && ln -s ../conf-available/reverse-proxy.conf .

ARG BASEXDIR=/home/transpect-control

RUN useradd -s /bin/bash -c "BaseX user" -g www-data -m -d ${BASEXDIR} -N basex
WORKDIR ${BASEXDIR}

ARG BASEXREPO=https://subversion.le-tex.de/common/basex/
ENV BASEXADMINPASSWD=popesti
ENV BASEXDBPORT=5710
ENV BASEXHTTPPORT=5711
ENV BASEXSTOPPORT=5712

ADD ${BASEXREPO} basexrevision.xml
RUN svn co ${BASEXREPO}

COPY apache-basex-svn.sh .

# This will create a different JSON file if the repo/branch has new commits.
# This will change the Dockerfile cache hash so that the cache is invalidated
# for the next RUN instruction.
ADD https://api.github.com/repos/transpect/control/commits?per_page=1 basex-svn-api.json
RUN git clone https://github.com/transpect/control ${BASEXDIR}/basex/webapp/control

ADD https://api.github.com/repos/transpect/basex-svn-api/commits?per_page=1 basex-svn-api.json
RUN git clone https://github.com/transpect/basex-svn-api

RUN cp basex-svn-api/jar/basex-svn-api.jar ${BASEXDIR}/basex/lib/custom 
RUN cp basex-svn-api/lib/* ${BASEXDIR}/basex/lib/custom

SHELL ["/bin/bash", "-c"]
RUN chown -R basex.www-data ${BASEXDIR}

#RUN ls -l ${BASEXDIR}/basex/webapp/control

EXPOSE 80
CMD ./apache-basex-svn.sh ${BASEXHTTPPORT} ${BASEXDBPORT} ${BASEXSTOPPORT} ${BASEXADMINPASSWD}

