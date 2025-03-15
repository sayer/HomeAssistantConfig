#!/bin/bash

# usage: ./update_config.sh MODEL_YEAR
# This script replaces tokens in configuration.template.yaml and writes to configuration.yaml

# Check if model year parameter is provided
if [ $# -ne 1 ]; then
    echo "Usage: ./update_config.sh MODEL_YEAR"
    exit 1
fi

MODEL_YEAR=$1
CONFIG_TEMPLATE="/config/configuration.template.yaml"
CONFIG_FILE="/config/configuration.yaml"
BACKUP_FILE="/config/configuration.yaml.bak"

# Check if template file exists
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "Error: Template file $CONFIG_TEMPLATE not found"
    exit 1
fi

# Create backup of current config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
fi

# Make a copy of the template
cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"

# Determine values based on model year
if [ "$MODEL_YEAR" -ge 2020 ]; then
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="44"
    EXTERIOR_ACCENT_LIGHTS="45"
    VENT_FAN1="62"
    VENT_FAN2="62"
    OPTIMISTIC_MODE="true"
else
    DOCKING_LIGHTS_CODE="121"
    AWNING_LIGHTS="122"
    EXTERIOR_ACCENT_LIGHTS="123"
    VENT_FAN1="55"
    VENT_FAN2="56"
    OPTIMISTIC_MODE="false"
fi

# Replace tokens
sed -i "s/%%DOCKING_LIGHTS_CODE%%/$DOCKING_LIGHTS_CODE/g" "$CONFIG_FILE"
sed -i "s/%%AWNING_LIGHTS%%/$AWNING_LIGHTS/g" "$CONFIG_FILE"
sed -i "s/%%VENT_FAN1%%/$VENT_FAN1/g" "$CONFIG_FILE"
sed -i "s/%%VENT_FAN2%%/$VENT_FAN2/g" "$CONFIG_FILE"
sed -i "s/%%EXTERIOR_ACCENT_LIGHTS%%/$EXTERIOR_ACCENT_LIGHTS/g" "$CONFIG_FILE"
sed -i "s/%%OPTIMISTIC_MODE%%/$OPTIMISTIC_MODE/g" "$CONFIG_FILE"

echo "Configuration updated for model year $MODEL_YEAR"
echo "Tokens replaced:"
echo "  %%DOCKING_LIGHTS_CODE%% -> $DOCKING_LIGHTS_CODE"
echo "  %%OPTIMISTIC_MODE%% -> $OPTIMISTIC_MODE"
echo "Restart Home Assistant to apply changes"
