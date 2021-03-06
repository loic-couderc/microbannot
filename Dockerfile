FROM debian:jessie

MAINTAINER Loic Couderc <loic.couderc@univ-lille1.fr>

LABEL ANNOT.Name="MicrobAnnot" \
  ANNOT.Version="0.1" \
  ANNOT.Description="MicrobAnnot is a toolkit for microbial genome annotation (secondary metabolite analysis with antiSMASH and CRISPR discovering with CRISPRDetect)" \
  ANNOT.Vendor="bilille (Univ. Lille,  CNRS, Inserm, Inria, Institut Pasteur de Lille, CHRU Lille et IRCL)" \
  ANNOT.EDAM_Operation="['operation_2403', 'operation_0361']" \
  ANNOT.Requires="['antiSMASH/3.0.5', 'CRISPRDetect/beta_2_11']" \
  ANNOT.Provides="['run_antismash', 'run_crispr_detect']"

RUN rm /bin/sh && ln -s /bin/bash /bin/sh #to avoid /bin/sh: 1: source: not found

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install apt-transport-https
#RUN apt-get install -y --no-install-recommends apt-utils #to avoid debconf: delaying package configuration, since apt-utils is not installed
RUN apt-get install dialog #to avoid debconf: unable to initialize frontend: Dialog

#+-------------------------+
#| 1_ install redis server |
#+-------------------------+
RUN apt-get -y install redis-server

#+---------------------+
#| 2_ install runsmash |
#+---------------------+
ENV ANTISMASH_URL="https://bitbucket.org/antismash/antismash/downloads"
ENV ANTISMASH_VERSION="3.0.5"

# set up antiSMASH deb repo
ADD http://dl.secondarymetabolites.org/antismash.list /etc/apt/sources.list.d/antismash.list
ADD http://dl.secondarymetabolites.org/antismash.asc /tmp/
RUN apt-key add /tmp/antismash.asc


# grab all the dependencies
RUN apt-get update && \
    apt-get install -y \
        curl \
        default-jre-headless \
        diamond=0.7.11-1\
        fasttree \
        git \
        glimmerhmm \
        hmmer \
        hmmer2 \
        hmmer2-compat \
        libc6-i386 \
        muscle \
        ncbi-blast+ \
        prodigal \
        python-backports.lzma \
        python-biopython \
        python-cobra \
        python-excelerator \
        python-glpk \
        python-helperlibs \
        python-hiredis \
        python-libsbml \
        python-pyinotify \
        python-pyquery \
        python-pysvg \
        python-redis \
        python-requests \
        python-statsd \
        python-straight.plugin \
        python-subprocess32 \
        tigr-glimmer \
    && \
    apt-get clean -y && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get clean -y
RUN apt-get autoclean -y
RUN apt-get autoremove -y
RUN rm -rf /var/lib/apt/lists/*

# Grab antiSMASH
RUN curl -L ${ANTISMASH_URL}/antismash-${ANTISMASH_VERSION}.tar.gz > /tmp/antismash-${ANTISMASH_VERSION}.tar.gz && \
    tar xf /tmp/antismash-${ANTISMASH_VERSION}.tar.gz && \
    rm /tmp/antismash-${ANTISMASH_VERSION}.tar.gz


#ADD instance.cfg /antismash-${ANTISMASH_VERSION}/antismash/config/instance.cfg
RUN curl -L https://bitbucket.org/antismash/docker/raw/c63856cb69d7e51893e510118dec1ea91f09afee/runsmash-lite/instance.cfg > /antismash-${ANTISMASH_VERSION}/antismash/config/instance.cfg

# grab runSMASH
RUN git clone https://bitbucket.org/antismash/runsmash.git
RUN cd runsmash && git reset --hard f2168a0 && cd -

# compress the shipped profiles
WORKDIR /antismash-${ANTISMASH_VERSION}/antismash/specific_modules/nrpspks
RUN hmmpress abmotifs.hmm && hmmpress dockingdomains.hmm && hmmpress ksdomains.hmm && hmmpress nrpspksdomains.hmm
WORKDIR /antismash-${ANTISMASH_VERSION}/antismash/generic_modules/smcogs/
RUN hmmpress smcogs.hmm

WORKDIR /usr/local/bin
RUN ln -s /antismash-${ANTISMASH_VERSION}/run_antismash.py
RUN ln -s /eficaz/bin/eficaz2.5

RUN curl -L https://bitbucket.org/antismash/docker/raw/c63856cb69d7e51893e510118dec1ea91f09afee/runsmash-lite/entrypoint.sh > /entrypoint.sh

#+------------------+
#| 3_ install nginx |
#+------------------+
WORKDIR /
RUN echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" > /etc/apt/sources.list.d/nginx.list
ADD http://nginx.org/keys/nginx_signing.key /tmp
RUN apt-key add /tmp/nginx_signing.key
RUN apt-get update
RUN apt-get -y install nginx
ADD ./nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80 443

#+---------------------+
#| 4_ install websmash |
#+---------------------+
WORKDIR /
RUN apt-get update && apt-get install -y \
    git \
    python-pip

RUN git clone https://bitbucket.org/antismash/websmash.git
RUN cd websmash && git reset --hard c1a39d9 && cd -
ADD ./websmash/config/settings.py.tpl /websmash/config/settings.py.tpl
WORKDIR /websmash

RUN pip install -r requirements.txt && \
    pip install gunicorn

RUN apt-get install -y unzip
RUN curl -L http://antismash.secondarymetabolites.org/upload/example/NC_003888.3.zip > NC_003888.3.zip && unzip NC_003888.3.zip
RUN mv 2acd7e9e-4872-48d4-bae9-cac30ec52622 example && rm NC_003888.3.zip

#+---------------------+
#| 5_ install webannot |
#+---------------------+
WORKDIR /
RUN apt-get update && apt-get install -y \
    python3-pip \
    virtualenv

#Replace this by a git clone when repo
ADD ./webannot /webannot
WORKDIR  /webannot
RUN rm -rf flask
RUN virtualenv --python=/usr/bin/python3 flask
RUN flask/bin/pip install -r requirements.txt
RUN flask/bin/pip install gunicorn

#+------------------------+
#| 6_ setup command lines |
#+------------------------+
WORKDIR /usr/local/bin

RUN apt-get -y install python-scipy #to get ride of "UserWarning: cobra.io.mat is not be functional: ImportError No module named scipy.io"

ADD ./cmd_line/run_antismash .
RUN chmod 755 run_antismash

ADD ./cmd_line/run_crispr_detect .
RUN chmod 755 /usr/local/bin/run_crispr_detect

#+------------------------------+
# 7_ for configuration purposes |
#+------------------------------+
RUN pip install j2cli

#+---------+
# 8_ clean |
#+---------+
RUN apt-get autoremove --purge -y git curl
RUN rm -rf /usr/share/doc/*
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get clean && apt-get autoremove --purge -y

#+---------------------+
#| 9_ run all services |
#+---------------------+
WORKDIR /
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh
VOLUME [ "/config", "/websmash/upload/", "/webannot/upload/", "/databases", "/eficaz" ]
ENTRYPOINT /start.sh
