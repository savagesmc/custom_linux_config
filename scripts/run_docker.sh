#!/bin/bash

USER=`stat -c %U ${HOME}`
GROUP=`stat -c %G ${HOME}`
GID=`stat -c %g ${HOME}`

IS_WSL=`cat /proc/version | grep Microsoft`

if [[ ! -z $IS_WSL ]]; then
   HOME_=$(wslpath ${HOME} | cut -d"\\" -f1-3)
   HOME_WSL=$(wslpath -u ${HOME_})
   ADDUSER_SCRIPT=${HOME}/home/create_user_docker.sh
   RUN_ADDUSER=${HOME}/create_user_docker.sh
else
   HOME_=${HOME}
   ADDUSER_SCRIPT=${HOME}/create_user_docker.sh
   RUN_ADDUSER=${ADDUSER_SCRIPT}
fi

echo HOME_ ${HOME_}

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

PASSWORD=${USER}

create_adduser_script()
{
cat << EOF > $ADDUSER_SCRIPT
#!/bin/bash
groupadd -g ${GID} ${GROUP}
useradd -M -s /usr/bin/zsh -g ${GID} -u ${UID} ${USER}
echo ${USER}:${PASSWORD} | chpasswd
usermod -aG sudo ${USER}
echo created user ${USER}
EOF
chmod a+x $ADDUSER_SCRIPT
echo "adduser script $ADDUSER_SCRIPT created"
}

NVIDIA=""

TAG=$USER
INTERACTIVE="-d"

while getopts "hi:t:NI" arg; do
   case $arg in
      N)
         NVIDIA="--runtime=nvidia --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864"
         ;;
      i)
         IMAGE=$OPTARG
         ;;
      t)
         TAG=$OPTARG
         ;;
      I)
         INTERACTIVE="-it"
         ;;
      *)
         usage
         exit 1
         ;;
   esac
done
shift $((OPTIND-1))

MOUNTS="-v ${HOME_}:${HOME}"
for m in /mnt/*
do
   MOUNTS=${MOUNTS}" -v ${m}:${m}"
done

echo ${MOUNTS}

docker run $NVIDIA $INTERACTIVE --rm --privileged \
   ${MOUNTS} \
   --name $TAG \
   $OPTARG $IMAGE

# Create user account for $USER
create_adduser_script
docker exec $TAG /bin/bash -c $RUN_ADDUSER
rm $ADDUSER_SCRIPT

IPADDR=`docker inspect $TAG | grep \"IPAddress\": | cut -d":" -f 2 | sed 's/\"//g' | sed 's/,//g' | uniq`

cat <<EOF
  Created docker container $TAG.
  Access via ssh at $IPADDR or by:
     'docker exec -it $TAG /bin/bash'
EOF
