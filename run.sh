#!/bin/bash

directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
network=aa274_net

# Base Docker command
# -p 32768-32778
cmd=( \
	docker run -it --rm --init --privileged \
	--mount type=bind,src=$directory/catkin_ws,dst=/home/$USER/catkin_ws \
	--mount type=bind,src=$directory/.ros,dst=/home/$USER/.ros \
	--net $network \
	--user $USER)

# Parse arguments
while [[ $# -ge 2 && $1 == -* ]]; do
	if [[ $1 == "--display" ]]; then
		# Display argument is not passed to Docker
		display=$2
		shift
		shift
		continue
	elif [[ $1 == "--vncport" ]]; then
		# vncport argument is not passed to Docker
		vncport=$2
		shift
		shift
		continue
	elif [[ $1 == "--rosmaster" ]]; then
		# rosmaster argument is not passed to Docker
		rosmaster=$2
		shift
		shift
		continue
	elif [[ $1 == "--rosport" ]]; then
		# rosport argument is not passed to Docker
		rosport=$2
		shift
		shift
		continue
	fi

	# Add arguments to Docker command
	cmd+=($1 $2)
	shift
	shift
done

# Display options
if [[ -n $display ]]; then

	# Set vncport to default (display + 5900) if display > 0
	if [[ -z $vncport ]]; then
		vncport=$(($display + 5900))
	fi

	# Set VNC settings
	if [[ -n $vncport ]]; then
		cmd+=(-p $vncport:$vncport)

		# Prompt VNC password
		printf "\nRunning a VNC instance at localhost:${vncport} with the password created below.\n\n"
		while [[ ${#password} -lt 6 ]]; do
			read -p "VNC password (6-8 characters): " -s password
		done
		printf "\n\n"

		cmd+=( \
			--env "VNCPASSWD=$password" \
			--env "VNCPORT=$vncport")
	fi
	cmd+=(--env "DISPLAY=:$display")
elif [[ -n $DISPLAY ]]; then
	if [[ $(uname) == 'Darwin' ]]; then
		cmd+=(--env "DISPLAY=host.docker.internal:0")
	else
		cmd+=(--env "DISPLAY=$DISPLAY")
	fi
fi

# Set rosport to default (11311)
if [[ -z $rosport ]]; then
	rosport=11311
fi

# Set rosmaster to default (master)
if [[ -z $rosmaster ]]; then
	rosmaster="master"
fi

# Configure ROS ports
cmd+=(--env "ROS_MASTER_URI=http://$rosmaster:$rosport")
if [[ "$rosmaster" != "master" ]]; then
	cmd+=(--env "ROS_HOSTNAME=$HOSTNAME")
	num_containers=$(docker container ls | grep aa274 | wc -l)
	port_mapping_start=$((32768 + num_containers * 32))
	port_mapping_range="$port_mapping_start-$((port_mapping_start+31))"
	cmd+=(--publish "$port_mapping_range:$port_mapping_range")
	cmd+=(--env "PORT_MAPPING_START=$port_mapping_start")
fi

# Application specific options
args="$@"
if [[ $* == *roscore* ]]; then
	# Name the roscore container 'master' so that other nodes can reach it
	cmd+=(--name $rosmaster)
elif [[ $* == *jupyter* ]]; then
	cmd+=(--publish 8888:8888)
	args+=(--ip=0.0.0.0)
fi

# Run command
echo ${cmd[@]}
echo ${args[@]}
${cmd[@]} aa274 ${args[@]}
