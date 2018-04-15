#!/bin/bash

USER=`stat -c %U ${HOME}`
GROUP=`stat -c %G ${HOME}`
GID=`stat -c %g ${HOME}`

usage()
{
cat << EOF
   run_docker.sh <options> <docker_run_options>
      options:
         -N    =>  run as nvidia-docker container
         -i    =>  docker image to be run
         -t    =>  label to tag the container with
         -I    =>  run interactive
         -h    =>  this help
EOF
}

ADDUSER_SCRIPT=${HOME}/create_user_docker.sh

PASSWORD=${USER}

create_adduser_script()
{
echo "#!/bin/bash" > $ADDUSER_SCRIPT
echo "groupadd -g ${GID} ${GROUP}" >> $ADDUSER_SCRIPT
echo "useradd -M -s /usr/bin/zsh -g ${GID} -u ${UID} ${USER}" >> $ADDUSER_SCRIPT
echo "echo ${USER}:${PASSWORD} | chpasswd" >> $ADDUSER_SCRIPT
echo "usermod -aG sudo ${USER}" >> $ADDUSER_SCRIPT
chmod a+x $ADDUSER_SCRIPT
}


NVIDIA=""

TAG=$USER

while getopts "hi:t:NI" arg; do
   case $arg in
      N)
         NVIDIA="--runtime=nvidia"
         ;;
      i)
         IMAGE=$OPTARG
         ;;
      t)
         TAG=$OPTARG
         ;;
      *)
         usage
         exit 1
         ;;
   esac
done
shift $((OPTIND-1))

docker run $NVIDIA -d --rm --privileged \
   -v $HOME:$HOME \
   --name $TAG \
   $IMAGE \
   $OPTARG

# Create user account for $USER
create_adduser_script
docker exec -d $TAG $ADDUSER_SCRIPT
rm $ADDUSER_SCRIPT

IPADDR=`docker inspect $TAG | grep \"IPAddress\": | cut -d":" -f 2 | sed 's/\"//g' | sed 's/,//g' | uniq`

cat <<EOF
  Created docker container $TAG.
  Access via ssh at $IPADDR or by:
     'docker exec -it $TAG /bin/bash'
EOF
