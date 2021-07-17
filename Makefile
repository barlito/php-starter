#Vars
stack_name=stack_name
project_url=starter.local.barlito.fr
app_container_id = $(shell docker ps --filter name="$(stack_name)_nginx" -q)

# Include all make rules from submodule
include make/entrypoint.mk
