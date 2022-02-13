import os
import json
import shutil
from jsonschema import validate

def validate_configuration(workflow_configuration_filename):
    # Get workflow configuration schema
    workflow_config_schema_fd = open('workflow-configuration.schema.json')
    workflow_config_schema = json.load(workflow_config_schema_fd)
    workflow_config_schema_fd.close()

    # Get workflow configuration
    workflow_config_fd = open(workflow_configuration_filename)
    workflow_config = json.load(workflow_config_fd)
    workflow_config_fd.close()

    # Get workflow configuration defaults
    workflow_config_defaults_fd = open('workflow-configuration.defaults.json')
    workflow_config_defaults = json.load(workflow_config_defaults_fd)
    workflow_config_defaults_fd.close()

    # Merge
    effective_workflow_config = merge(workflow_config, workflow_config_defaults)

    # Validate effective workflow configuration against the schema
    try:
        validate(effective_workflow_config, workflow_config_schema)
    except:
        return None

    # Recreate existing output directory
    output_directory = effective_workflow_config.get('output_directory')

    if os.path.isdir(output_directory):
        shutil.rmtree(output_directory)
    os.mkdir(output_directory)

    # Transfer effective workflow configuration file to output directory
    effective_workflow_config_filename = os.path.join(output_directory, 'workflow-configuration.json')
    with open(effective_workflow_config_filename, 'w') as outfile:
        json.dump(effective_workflow_config, outfile, indent=2)

    shutil.copy('workflow-configuration.schema.json', output_directory)

    return effective_workflow_config_filename

def merge(source, destination):
    for key, value in source.items():
        if isinstance(value, dict):
            node = destination.setdefault(key, {})
            merge(value, node)
        else:
            destination[key] = value

    return destination
