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

# Shade configurations for different model years
# This section can be updated with specific shade codes for each model year range

# 2023+ Model configurations
function configure_2023_plus() {
    # General device codes
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="44"
    EXTERIOR_ACCENT_LIGHTS="45"
    VENT_FAN1="62"
    VENT_FAN2="62"
    OPTIMISTIC_MODE="true"
    
    # Shade RV-C codes
    WINDSHIELD_DAY_CODE="1"
    DRIVER_DAY_CODE="2"
    PASSENGER_DAY_CODE="3"
    ENTRY_DOOR_DAY_CODE="4"
    WINDSHIELD_NIGHT_CODE="5"
    DRIVER_NIGHT_CODE="6"
    PASSENGER_NIGHT_CODE="7"
    ENTRY_DOOR_NIGHT_CODE="8"
    DINETTE_DAY_CODE="10"
    MID_BATH_NIGHT_CODE="12"
    DINETTE_NIGHT_CODE="14"
    REAR_BATH_NIGHT_CODE="16"
    TOP_BUNK_NIGHT_CODE="17"
    DS_LIVING_DAY_CODE="18"
    BEDROOM_DRESSER_DAY_CODE="20"
    BOTTOM_BUNK_NIGHT_CODE="21"
    DS_LIVING_NIGHT_CODE="22"
    BEDROOM_DRESSER_NIGHT_CODE="24"
    BEDROOM_FRONT_DAY_CODE="25"
    BEDROOM_REAR_DAY_CODE="27"
    BEDROOM_FRONT_NIGHT_CODE="29"
    BEDROOM_REAR_NIGHT_CODE="31"
}

# 2020-2022 Model configurations
function configure_2020_to_2022() {
    # General device codes
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="44"
    EXTERIOR_ACCENT_LIGHTS="45"
    VENT_FAN1="62"
    VENT_FAN2="62"
    OPTIMISTIC_MODE="true"
    
    # Shade RV-C codes (may be different from 2023+)
    WINDSHIELD_DAY_CODE="1"
    DRIVER_DAY_CODE="2"
    PASSENGER_DAY_CODE="3"
    ENTRY_DOOR_DAY_CODE="4"
    WINDSHIELD_NIGHT_CODE="5"
    DRIVER_NIGHT_CODE="6"
    PASSENGER_NIGHT_CODE="7"
    ENTRY_DOOR_NIGHT_CODE="8"
    DINETTE_DAY_CODE="10"
    MID_BATH_NIGHT_CODE="12"
    DINETTE_NIGHT_CODE="14"
    REAR_BATH_NIGHT_CODE="16"
    TOP_BUNK_NIGHT_CODE="17"
    DS_LIVING_DAY_CODE="18"
    BEDROOM_DRESSER_DAY_CODE="20"
    BOTTOM_BUNK_NIGHT_CODE="21"
    DS_LIVING_NIGHT_CODE="22"
    BEDROOM_DRESSER_NIGHT_CODE="24"
    BEDROOM_FRONT_DAY_CODE="25"
    BEDROOM_REAR_DAY_CODE="27"
    BEDROOM_FRONT_NIGHT_CODE="29"
    BEDROOM_REAR_NIGHT_CODE="31"
}

# Pre-2020 Model configurations
function configure_pre_2020() {
    # General device codes
    DOCKING_LIGHTS_CODE="121"
    AWNING_LIGHTS="122"
    EXTERIOR_ACCENT_LIGHTS="123"
    VENT_FAN1="55"
    VENT_FAN2="56"
    OPTIMISTIC_MODE="false"
    
    # Shade RV-C codes (may be different from newer models)
    WINDSHIELD_DAY_CODE="1"
    DRIVER_DAY_CODE="2"
    PASSENGER_DAY_CODE="3"
    ENTRY_DOOR_DAY_CODE="4"
    WINDSHIELD_NIGHT_CODE="5"
    DRIVER_NIGHT_CODE="6"
    PASSENGER_NIGHT_CODE="7"
    ENTRY_DOOR_NIGHT_CODE="8"
    DINETTE_DAY_CODE="10"
    MID_BATH_NIGHT_CODE="12"
    DINETTE_NIGHT_CODE="14"
    REAR_BATH_NIGHT_CODE="16"
    TOP_BUNK_NIGHT_CODE="17"
    DS_LIVING_DAY_CODE="18"
    BEDROOM_DRESSER_DAY_CODE="20"
    BOTTOM_BUNK_NIGHT_CODE="21"
    DS_LIVING_NIGHT_CODE="22"
    BEDROOM_DRESSER_NIGHT_CODE="24"
    BEDROOM_FRONT_DAY_CODE="25"
    BEDROOM_REAR_DAY_CODE="27"
    BEDROOM_FRONT_NIGHT_CODE="29"
    BEDROOM_REAR_NIGHT_CODE="31"
}

# Apply the appropriate configuration based on model year
if [ "$MODEL_YEAR" -ge 2023 ]; then
    echo "Applying configuration for 2023+ models"
    configure_2023_plus
elif [ "$MODEL_YEAR" -ge 2020 ] && [ "$MODEL_YEAR" -le 2022 ]; then
    echo "Applying configuration for 2020-2022 models"
    configure_2020_to_2022
else
    echo "Applying configuration for pre-2020 models"
    configure_pre_2020
fi

# Display the model year and applied configuration
echo "Configured for model year: $MODEL_YEAR"

# Replace tokens
sed -i "s/%%DOCKING_LIGHTS_CODE%%/$DOCKING_LIGHTS_CODE/g" "$CONFIG_FILE"
sed -i "s/%%AWNING_LIGHTS%%/$AWNING_LIGHTS/g" "$CONFIG_FILE"
sed -i "s/%%VENT_FAN1%%/$VENT_FAN1/g" "$CONFIG_FILE"
sed -i "s/%%VENT_FAN2%%/$VENT_FAN2/g" "$CONFIG_FILE"
sed -i "s/%%EXTERIOR_ACCENT_LIGHTS%%/$EXTERIOR_ACCENT_LIGHTS/g" "$CONFIG_FILE"
sed -i "s/%%OPTIMISTIC_MODE%%/$OPTIMISTIC_MODE/g" "$CONFIG_FILE"

# Replace shade tokens
sed -i "s/%%WINDSHIELD_DAY_CODE%%/$WINDSHIELD_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DRIVER_DAY_CODE%%/$DRIVER_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%PASSENGER_DAY_CODE%%/$PASSENGER_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%ENTRY_DOOR_DAY_CODE%%/$ENTRY_DOOR_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%WINDSHIELD_NIGHT_CODE%%/$WINDSHIELD_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DRIVER_NIGHT_CODE%%/$DRIVER_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%PASSENGER_NIGHT_CODE%%/$PASSENGER_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%ENTRY_DOOR_NIGHT_CODE%%/$ENTRY_DOOR_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DINETTE_DAY_CODE%%/$DINETTE_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%MID_BATH_NIGHT_CODE%%/$MID_BATH_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DINETTE_NIGHT_CODE%%/$DINETTE_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%REAR_BATH_NIGHT_CODE%%/$REAR_BATH_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%TOP_BUNK_NIGHT_CODE%%/$TOP_BUNK_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DS_LIVING_DAY_CODE%%/$DS_LIVING_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_DRESSER_DAY_CODE%%/$BEDROOM_DRESSER_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BOTTOM_BUNK_NIGHT_CODE%%/$BOTTOM_BUNK_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%DS_LIVING_NIGHT_CODE%%/$DS_LIVING_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_DRESSER_NIGHT_CODE%%/$BEDROOM_DRESSER_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_FRONT_DAY_CODE%%/$BEDROOM_FRONT_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_REAR_DAY_CODE%%/$BEDROOM_REAR_DAY_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_FRONT_NIGHT_CODE%%/$BEDROOM_FRONT_NIGHT_CODE/g" "$CONFIG_FILE"
sed -i "s/%%BEDROOM_REAR_NIGHT_CODE%%/$BEDROOM_REAR_NIGHT_CODE/g" "$CONFIG_FILE"

echo "==============================================="
echo "Configuration updated for model year $MODEL_YEAR"
echo "==============================================="
echo "Tokens replaced:"
echo ""
echo "General device codes:"
echo "  %%DOCKING_LIGHTS_CODE%% -> $DOCKING_LIGHTS_CODE"
echo "  %%AWNING_LIGHTS%% -> $AWNING_LIGHTS"
echo "  %%EXTERIOR_ACCENT_LIGHTS%% -> $EXTERIOR_ACCENT_LIGHTS"
echo "  %%VENT_FAN1%% -> $VENT_FAN1"
echo "  %%VENT_FAN2%% -> $VENT_FAN2"
echo "  %%OPTIMISTIC_MODE%% -> $OPTIMISTIC_MODE"
echo ""
echo "Window shade codes (showing first 5 of 22):"
echo "  %%WINDSHIELD_DAY_CODE%% -> $WINDSHIELD_DAY_CODE"
echo "  %%DRIVER_DAY_CODE%% -> $DRIVER_DAY_CODE"
echo "  %%PASSENGER_DAY_CODE%% -> $PASSENGER_DAY_CODE"
echo "  %%ENTRY_DOOR_DAY_CODE%% -> $ENTRY_DOOR_DAY_CODE"
echo "  %%WINDSHIELD_NIGHT_CODE%% -> $WINDSHIELD_NIGHT_CODE"
echo "  (plus 17 additional shade codes)"
echo ""
echo "To apply these changes:"
echo "1. Restart Home Assistant"
echo "2. Check that all window shades are functioning correctly"
echo ""
echo "To use these tokens in configuration.template.yaml,"
echo "replace instance numbers with the corresponding token, for example:"
echo "command_topic: \"RVC/WINDOW_SHADE_CONTROL_COMMAND/%%WINDSHIELD_DAY_CODE%%/set\""
