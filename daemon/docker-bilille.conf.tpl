description "Bio-informatic tools for bio-analysis"
author "Loïc Couderc"

start on filesystem and started docker
stop on runlevel [!2345]

# Automatically restart process if crashed (limit 3 times in 4 minutes)
respawn limit 3 240

# our process forks(clones) many times (maybe 10) so expect fork, or expect daemon are useless.
# we use the technique explained here http://stackoverflow.com/questions/12200217/can-upstart-expect-respawn-be-used-on-processes-that-fork-more-than-twice

# start the container in the pre-start script
pre-start script
    /bin/sh "{{ bilille.install_dir }}/create_output_dir.sh"
	/bin/ln -s -f "{{ bilille.install_dir }}/antismash/example" "{{ bilille.output_dir }}/example"
    # wait (if necessary) for our docker context to be accessible
    while [ ! -f {{ bilille.install_dir }}/docker-compose.yml ]
    do
      sleep 1
    done
    /usr/local/bin/docker-compose -f {{ bilille.install_dir }}/docker-compose.yml up -d
end script

# run a process that stays up while our docker container is up. Upstart will track this PID
script
    sleepWhileAppIsUp(){
        while docker ps | grep -q "$1"; do
            sleep 2
        done
    }

    sleepWhileAppIsUp "bilille_"
end script

# stop docker container after the stop event has completed
post-stop script
    if docker ps | grep -q bilille_;
    then
        /usr/local/bin/docker-compose -f {{ bilille.install_dir }}/docker-compose.yml stop
    fi
end script

