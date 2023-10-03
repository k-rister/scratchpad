#!/bin/bash

# user configurable options #####################################################

target="centosstream9-rt"

userenv="default"

#osruntime="chroot"
osruntime="podman"
stress_ng_osruntime="chroot"

tools="no"
#tools="yes"

#stress_ng="no"
stress_ng="yes"

samples=3

mode="run"
#mode="test"

from_file="oslat.json"

#################################################################################

DO_JQ_FILENAME="${from_file}.run"
cp "${from_file}" "${DO_JQ_FILENAME}"

# jq interface that handles the redirection to a temporary file and
# then replacement of the original file
# all the functions below use this to avoid having to replicate that
# file handling logic over and over again
function do_jq() {
    jq "$@" "${DO_JQ_FILENAME}" > "${DO_JQ_FILENAME}.tmp"
    if [ $? == 0 ]; then
	mv "${DO_JQ_FILENAME}.tmp" "${DO_JQ_FILENAME}"
	return 0
    else
	return 1
    fi
}

# change an existing run-params parameter value
function override_run_param() {
    local param=$1; shift
    local value=$1; shift

    do_jq --arg param "${param}" --arg value "${value}" '."run-params"[$param] = $value'
}

# add a new parameter to the run-params object
function add_run_param() {
    local param=$1; shift
    local value=$1; shift

    do_jq --arg param "${param}" --arg value "${value}" '."run-params" += { ($param): $value }'
}

# disable tools by emptying the array
function no_tools() {
    do_jq '."tool-params" = []'
}

# add a tag to the tags object
function add_tag() {
    local tag=$1; shift
    local value=$1; shift

    do_jq --arg tag "${tag}" --arg value "${value}" '."tags" += { ($tag): $value }'
}

# insert a new endpoint object to the endpoints array at index 0
function add_endpoint_obj() {
    do_jq '."endpoints" |= [{}] + .'
}

# add a new property to the endpoint object at endpoints array index 0
function add_endpoint_obj_property() {
    local property=$1; shift
    local value=$1; shift

    do_jq --arg property "${property}" --arg value "${value}" '."endpoints"[0] += { ($property): $value }'
}

# add an empty config array property to the endpoint object at
# endpoints array index 0
function add_endpoint_cfg() {
    do_jq '."endpoints"[0] += { "config": [] }'
}

# insert a config object to the config array at index 0 for the
# endpoint object at endpoints array index 0
function add_endpoint_cfg_obj() {
    do_jq '."endpoints"[0]."config" |= [{ "settings": {} }] + .'
}

# create a targets property with the default value to the config
# object at config array index 0 for the endpoint object at endpoints
# array index 0
function add_endpoint_cfg_obj_default_target() {
    do_jq '."endpoints"[0]."config"[0] += { "targets": "default" }'
}

# create a an empty targets array property to the config object at
# config array index 0 for the endpoint object at endpoints array
# index 0
function add_endpoint_cfg_obj_target_obj() {
    do_jq '."endpoints"[0]."config"[0] += { "targets": [] }'
}

# insert a target object at targets array index 0 to the config object
# at config array index 0 for the endpoint object at endpoints array
# index 0
function add_endpoint_cfg_obj_target_obj_entry() {
    local role=$1; shift
    local ids=$1; shift

    do_jq --arg role "${role}" --arg ids "${ids}" '."endpoints"[0]."config"[0]."targets" |= [{ "role": $role, "ids": $ids }] + .'
}

# add a settings property to the settings object of the config object
# at config array index 0 for the endpoint object at endpoints array
# index 0
function add_endpoint_cfg_obj_setting() {
    local setting=$1; shift
    local value=$1; shift

    do_jq --arg setting "${setting}" --arg value "${value}" '."endpoints"[0]."config"[0]."settings" += { ($setting): $value }'
}

#################################################################################

override_run_param "num-samples" "${samples}"
override_run_param "max-sample-failures" "${samples}"

if [ "${tools}" == "no" ]; then
    no_tools
fi

case "${target}" in
    "centosstream9-rt")
	add_tag "clients" "1"
	add_tag "stress-ng" "${stress_ng}"
	add_tag "endpoint" "remotehost"
	add_tag "distro" "${target}"
	add_tag "tuned" "cpu-partitioning"
	add_tag "userenv" "${userenv}"
	add_tag "osruntime" "${osruntime}"

	add_endpoint_obj
	add_endpoint_obj_property "type" "remotehost"
	add_endpoint_obj_property "host" "192.168.12.169"
	add_endpoint_obj_property "user" "root"
	add_endpoint_obj_property "client" "1"
	add_endpoint_obj_property "userenv" "${userenv}"
	add_endpoint_obj_property "osruntime" "${osruntime}"

	add_endpoint_cfg
	add_endpoint_cfg_obj
	add_endpoint_cfg_obj_default_target
	add_endpoint_cfg_obj_setting "cpu-partitioning" "1"

	if [ "${stress_ng}" == "yes" ]; then
	    add_endpoint_obj_property "server" "1"

	    add_endpoint_cfg_obj
	    add_endpoint_cfg_obj_target_obj
	    add_endpoint_cfg_obj_target_obj_entry "server" "1"
	    add_endpoint_cfg_obj_setting "cpu-partitioning" "0"

	    add_tag "stress-ng_osruntime" "${stress_ng_osruntime}"
	    add_endpoint_cfg_obj
	    add_endpoint_cfg_obj_target_obj
	    add_endpoint_cfg_obj_target_obj_entry "server" "1"
	    add_endpoint_cfg_obj_setting "osruntime" "${stress_ng_osruntime}"
	fi
	;;
    "some-other-target")
	# this could be an alternative test environment such as
	# something that would use the k8s endpoint instead of the
	# remotehost
	;;
esac

#################################################################################

case "${mode}" in
    "test")
	jq . "${DO_JQ_FILENAME}"
	;;
    "run")
	crucible run --from-file "${DO_JQ_FILENAME}"
	;;
    *)
	echo "ERROR: Invalid mode '${mode}'"
	exit 1
	;;
esac
