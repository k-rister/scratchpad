This example has an `oslat.json` template that the `run.sh` script
ingests and adds information to (or deletes information from) based on
the variables defined at the top of the `run.sh` using the "API" that
is defined.

The "API" uses `jq` to perform "well known" operations against the
JSON template file which results in the creation of the
`oslat.json.run` file.  This file is then submitted to crucible using
the `run --from-file <file>` interface.

With this methodology the template can remain "static" (unless the
user desires it to change via manual edits) and a new JSON file is
rendered on each execution of the `run.sh` script based on the values
defined in it.

The "API" defined here is meant to be a first draft attempt at
providing something useful for this type of workflow.  Please feel
free to add comments here on ways to improve and/or change the "API"
or other parts of the script.

The goal is to eventually come up with a usable library of functions
for placement in Crucible that a user could make use of for authoring
their own JSON files "on the fly" from templates (or potentially
scratch).
