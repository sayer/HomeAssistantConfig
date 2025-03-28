#!/bin/bash

# usage: ./update_config.sh MODEL_YEAR [CONFIG_DIR]
# This script replaces tokens in configuration.template.yaml and writes to configuration.yaml
# If CONFIG_DIR is provided, it will use that as the base directory instead of current directory

# Check if model year parameter is provided
if [ $# -lt 1 ]; then
    echo "Usage: ./update_config.sh MODEL_YEAR [CONFIG_DIR]"
    exit 1
fi

MODEL_YEAR=$1
CONFIG_DIR="."

# If a config directory is provided, use it
if [ $# -gt 1 ]; then
    CONFIG_DIR=$2
fi

# Use paths relative to the config directory
CONFIG_TEMPLATE="${CONFIG_DIR}/configuration.template.yaml"
CONFIG_FILE="${CONFIG_DIR}/configuration.yaml"
BACKUP_FILE="${CONFIG_DIR}/configuration.yaml.bak"

# Check if template file exists
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "Error: Template file $CONFIG_TEMPLATE not found"
    exit 1
fi

# Check if we have write permissions
if [ -f "$CONFIG_FILE" ] && [ ! -w "$CONFIG_FILE" ]; then
    echo "Error: No write permission to $CONFIG_FILE"
    exit 1
fi

if [ ! -w "$(dirname "$CONFIG_FILE")" ]; then
    echo "Error: No write permission to directory $(dirname "$CONFIG_FILE")"
    exit 1
fi

# Create backup of current config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
fi

# Make a copy of the template
cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"

# Since macOS uses an old version of bash that doesn't support associative arrays,
# we'll use a simpler approach with separate variables

# Shade names and unique IDs (token -> human-readable name, unique_id)
# Format: NAME_WINDSHIELD_DAY="Windshield Day" UID_WINDSHIELD_DAY="windshield_day"
NAME_WINDSHIELD_DAY="Windshield Day"; UID_WINDSHIELD_DAY="windshield_day"
NAME_DRIVER_DAY="Driver Day"; UID_DRIVER_DAY="driver_day"
NAME_PASSENGER_DAY="Passenger Day"; UID_PASSENGER_DAY="passenger_day"
NAME_ENTRY_DOOR_DAY="Entry Door Day"; UID_ENTRY_DOOR_DAY="entry_door_day"
NAME_WINDSHIELD_NIGHT="Windshield Night"; UID_WINDSHIELD_NIGHT="windshield_night"
NAME_DRIVER_NIGHT="Driver Night"; UID_DRIVER_NIGHT="driver_night"
NAME_PASSENGER_NIGHT="Passenger Night"; UID_PASSENGER_NIGHT="passenger_night"
NAME_ENTRY_DOOR_NIGHT="Entry Door Night"; UID_ENTRY_DOOR_NIGHT="entry_door_night"
NAME_DINETTE_DAY="Dinette Day"; UID_DINETTE_DAY="dinette_day"
NAME_MID_BATH_NIGHT="Mid Bath Night"; UID_MID_BATH_NIGHT="mid_bath_night"
NAME_DINETTE_NIGHT="Dinette Night"; UID_DINETTE_NIGHT="dinette_night"
NAME_REAR_BATH_NIGHT="Rear Bath Night"; UID_REAR_BATH_NIGHT="rear_bath_night"
NAME_TOP_BUNK_NIGHT="Top Bunk Night"; UID_TOP_BUNK_NIGHT="top_bunk_night"
NAME_DS_LIVING_DAY="D/S Living Room Day"; UID_DS_LIVING_DAY="ds_living_day"
NAME_BEDROOM_DRESSER_DAY="Bedroom Dresser Day"; UID_BEDROOM_DRESSER_DAY="bedroom_dreser_day"
NAME_BOTTOM_BUNK_NIGHT="Bottom Bunk Night"; UID_BOTTOM_BUNK_NIGHT="bottom_bunk_night"
NAME_DS_LIVING_NIGHT="D/S Living Room Night"; UID_DS_LIVING_NIGHT="ds_living_night"
NAME_BEDROOM_DRESSER_NIGHT="Bedroom Dresser Night"; UID_BEDROOM_DRESSER_NIGHT="bedroom_dresser_night"
NAME_BEDROOM_FRONT_DAY="Bedroom Front Day"; UID_BEDROOM_FRONT_DAY="bedroom_front_day"
NAME_BEDROOM_REAR_DAY="Bedroom Rear Day"; UID_BEDROOM_REAR_DAY="bedroom_rear_day"
NAME_BEDROOM_FRONT_NIGHT="Bedroom Front Night"; UID_BEDROOM_FRONT_NIGHT="bedroom_front_night"
NAME_BEDROOM_REAR_NIGHT="Bedroom Rear Night"; UID_BEDROOM_REAR_NIGHT="bedroom_rear_night"

# Define all shade tokens (used for looping)
ALL_SHADE_TOKENS="WINDSHIELD_DAY DRIVER_DAY PASSENGER_DAY ENTRY_DOOR_DAY WINDSHIELD_NIGHT DRIVER_NIGHT PASSENGER_NIGHT ENTRY_DOOR_NIGHT DINETTE_DAY MID_BATH_NIGHT DINETTE_NIGHT REAR_BATH_NIGHT TOP_BUNK_NIGHT DS_LIVING_DAY BEDROOM_DRESSER_DAY BOTTOM_BUNK_NIGHT DS_LIVING_NIGHT BEDROOM_DRESSER_NIGHT BEDROOM_FRONT_DAY BEDROOM_REAR_DAY BEDROOM_FRONT_NIGHT BEDROOM_REAR_NIGHT"

# Shade configurations for different model years
# 2023+ Model codes
CODE_2023_WINDSHIELD_DAY="1"
CODE_2023_DRIVER_DAY="2"
CODE_2023_PASSENGER_DAY="3"
CODE_2023_ENTRY_DOOR_DAY="4"
CODE_2023_WINDSHIELD_NIGHT="5"
CODE_2023_DRIVER_NIGHT="6"
CODE_2023_PASSENGER_NIGHT="7"
CODE_2023_ENTRY_DOOR_NIGHT="8"
CODE_2023_DINETTE_DAY="10"
CODE_2023_MID_BATH_NIGHT="12"
CODE_2023_DINETTE_NIGHT="14"
CODE_2023_REAR_BATH_NIGHT="16"
CODE_2023_TOP_BUNK_NIGHT="17"
CODE_2023_DS_LIVING_DAY="18"
CODE_2023_BEDROOM_DRESSER_DAY="20"
CODE_2023_BOTTOM_BUNK_NIGHT="21"
CODE_2023_DS_LIVING_NIGHT="22"
CODE_2023_BEDROOM_DRESSER_NIGHT="24"
CODE_2023_BEDROOM_FRONT_DAY="25"
CODE_2023_BEDROOM_REAR_DAY="27"
CODE_2023_BEDROOM_FRONT_NIGHT="29"
CODE_2023_BEDROOM_REAR_NIGHT="31"

# 2020-2022 Model codes (same as 2023+ in this case, but kept separate for possible future differences)
CODE_2020_WINDSHIELD_DAY="1"
CODE_2020_DRIVER_DAY="2"
CODE_2020_PASSENGER_DAY="3"
CODE_2020_ENTRY_DOOR_DAY="4"
CODE_2020_WINDSHIELD_NIGHT="5"
CODE_2020_DRIVER_NIGHT="6"
CODE_2020_PASSENGER_NIGHT="7"
CODE_2020_ENTRY_DOOR_NIGHT="8"
CODE_2020_DINETTE_DAY="10"
CODE_2020_MID_BATH_NIGHT="12"
CODE_2020_DINETTE_NIGHT="14"
CODE_2020_REAR_BATH_NIGHT="16"
CODE_2020_TOP_BUNK_NIGHT="17"
CODE_2020_DS_LIVING_DAY="18"
CODE_2020_BEDROOM_DRESSER_DAY="20"
CODE_2020_BOTTOM_BUNK_NIGHT="21"
CODE_2020_DS_LIVING_NIGHT="22"
CODE_2020_BEDROOM_DRESSER_NIGHT="24"
CODE_2020_BEDROOM_FRONT_DAY="25"
CODE_2020_BEDROOM_REAR_DAY="27"
CODE_2020_BEDROOM_FRONT_NIGHT="29"
CODE_2020_BEDROOM_REAR_NIGHT="31"

# Pre-2020 Model codes (same as others in this case, but kept separate for possible future differences)
CODE_PRE2020_WINDSHIELD_DAY="1"
CODE_PRE2020_DRIVER_DAY="2"
CODE_PRE2020_PASSENGER_DAY="3"
CODE_PRE2020_ENTRY_DOOR_DAY="4"
CODE_PRE2020_WINDSHIELD_NIGHT="5"
CODE_PRE2020_DRIVER_NIGHT="6"
CODE_PRE2020_PASSENGER_NIGHT="7"
CODE_PRE2020_ENTRY_DOOR_NIGHT="8"
CODE_PRE2020_DINETTE_DAY="10"
CODE_PRE2020_MID_BATH_NIGHT="12"
CODE_PRE2020_DINETTE_NIGHT="14"
CODE_PRE2020_REAR_BATH_NIGHT="16"
CODE_PRE2020_TOP_BUNK_NIGHT="17"
CODE_PRE2020_DS_LIVING_DAY="18"
CODE_PRE2020_BEDROOM_DRESSER_DAY="20"
CODE_PRE2020_BOTTOM_BUNK_NIGHT="21"
CODE_PRE2020_DS_LIVING_NIGHT="22"
CODE_PRE2020_BEDROOM_DRESSER_NIGHT="24"
CODE_PRE2020_BEDROOM_FRONT_DAY="25"
CODE_PRE2020_BEDROOM_REAR_DAY="27"
CODE_PRE2020_BEDROOM_FRONT_NIGHT="29"
CODE_PRE2020_BEDROOM_REAR_NIGHT="31"

# Function to generate a single shade YAML entry
generate_shade_entry() {
    local token=$1
    local code=$2
    local name=$(eval echo \$NAME_$token)
    local uid=$(eval echo \$UID_$token)
    
    # Add a comment before the shade entry
    echo "    # Shade configuration for $name (code: $code)
    - name: \"$name\"
      unique_id: \"$uid\"
      state_topic: \"RVC/WINDOW_SHADE_CONTROL_STATUS/$code\"
      position_topic: \"RVC/WINDOW_SHADE_CONTROL_STATUS/$code\"
      value_template: >-
        {% if not value_json is defined %}closed
        {% else %}
        {% set motor = value_json['motor status definition'] | default('inactive') %}
        {% set last_cmd = value_json['last command definition'] | default('none') %}
        {% if motor == 'active' %}
          {% if last_cmd == 'toggle forward' %}opening
          {% elif last_cmd == 'toggle reverse' %}closing
          {% else %}closed{% endif %}
        {% else %}
          {% if last_cmd == 'toggle forward' %}open
          {% elif last_cmd == 'toggle reverse' %}closed
          {% else %}closed{% endif %}
        {% endif %}
        {% endif %}
      command_topic: \"RVC/WINDOW_SHADE_CONTROL_COMMAND/$code/set\"
      payload_open: '{\"instance\": $code, \"command\": \"open\"}'
      payload_close: '{\"instance\": $code, \"command\": \"close\"}'
      payload_stop: '{\"instance\": $code, \"command\": \"stop\"}'
      payload_available: \"online\"
      payload_not_available: \"offline\"
      state_opening: \"opening\"
      state_closing: \"closing\"
      state_open: \"open\"
      state_closed: \"closed\"
      position_template: >-
        {% set last_cmd = value_json['last command definition'] %}
        {% if last_cmd == 'toggle forward' %}
        100
        {% elif last_cmd == 'toggle reverse' %}
        0
        {% else %}
        {{ value_json.position | default(value_json['motor duty']) | default(0) }}
        {% endif %}
      position_open: 100
      position_closed: 0
      set_position_topic: \"RVC/WINDOW_SHADE_CONTROL_COMMAND/$code/set\"
      set_position_template: '{\"instance\": $code, \"position\": {{ position }}}'
      availability_template: >-
        {% if value_json is defined and value_json['motor status definition'] is defined %}
        online
        {% else %}
        offline
        {% endif %}
      optimistic: false

"
}

# Function to generate all shade YAML entries
generate_all_shades() {
    local prefix=$1
    local yaml_string=""
    
    # Add header comment
    yaml_string+="    # Window shade configurations for model year $MODEL_YEAR\n"
    
    for token in $ALL_SHADE_TOKENS; do
        local code_var="${prefix}_${token}"
        local code=$(eval echo \$$code_var)
        if [ -n "$code" ]; then
            # Add an extra newline before each shade (except the first one)
            if [ -n "$yaml_string" ]; then
                yaml_string+="\n"
            fi
            yaml_string+=$(generate_shade_entry "$token" "$code")
        fi
    done
    
    echo "$yaml_string"
}

# Function to set all shade tokens
set_shade_tokens() {
    local prefix=$1
    
    for token in $ALL_SHADE_TOKENS; do
        local code_var="${prefix}_${token}"
        local code=$(eval echo \$$code_var)
        if [ -n "$code" ]; then
            eval "${token}_CODE=$code"
        fi
    done
}

# 2023+ Model configurations
configure_2023_plus() {
    # General device codes
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="44"
    EXTERIOR_ACCENT_LIGHTS="45"
    VENT_FAN1="62"
    VENT_FAN2="62"
    OPTIMISTIC_MODE="true"
    
    # Set shade codes
    set_shade_tokens "CODE_2023"
}

# 2020-2022 Model configurations
configure_2020_to_2022() {
    # General device codes
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="44"
    EXTERIOR_ACCENT_LIGHTS="45"
    VENT_FAN1="62"
    VENT_FAN2="62"
    OPTIMISTIC_MODE="true"
    
    # Set shade codes
    set_shade_tokens "CODE_2020"
}

# Pre-2020 Model configurations
configure_pre_2020() {
    # General device codes
    DOCKING_LIGHTS_CODE="121"
    AWNING_LIGHTS="122"
    EXTERIOR_ACCENT_LIGHTS="123"
    VENT_FAN1="55"
    VENT_FAN2="56"
    OPTIMISTIC_MODE="false"
    
    # Set shade codes
    set_shade_tokens "CODE_PRE2020"
}

# Apply the appropriate configuration based on model year
if [ "$MODEL_YEAR" -ge 2023 ]; then
    echo "Applying configuration for 2023+ models"
    configure_2023_plus
    SHADE_YAML=$(generate_all_shades "CODE_2023")
    MODEL_PREFIX="CODE_2023"
elif [ "$MODEL_YEAR" -ge 2020 ] && [ "$MODEL_YEAR" -le 2022 ]; then
    echo "Applying configuration for 2020-2022 models"
    configure_2020_to_2022
    SHADE_YAML=$(generate_all_shades "CODE_2020")
    MODEL_PREFIX="CODE_2020"
else
    echo "Applying configuration for pre-2020 models"
    configure_pre_2020
    SHADE_YAML=$(generate_all_shades "CODE_PRE2020")
    MODEL_PREFIX="CODE_PRE2020"
fi

# Display the model year and applied configuration
echo "Configured for model year: $MODEL_YEAR"

# Create a temporary file for sed operations in a safe location
TEMP_FILE=$(mktemp)
if [ $? -ne 0 ]; then
    # Fallback to local directory if mktemp fails
    TEMP_FILE="${CONFIG_DIR}/.temp_config.$$"
    touch "$TEMP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to create temporary file"
        exit 1
    fi
fi

# Another temporary file for the final config
TEMP_FILE2=$(mktemp)
if [ $? -ne 0 ]; then
    # Fallback to local directory if mktemp fails
    TEMP_FILE2="${CONFIG_DIR}/.temp_config2.$$"
    touch "$TEMP_FILE2"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to create second temporary file"
        rm -f "$TEMP_FILE"
        exit 1
    fi
fi

# Trap to clean up temporary files on exit
trap 'rm -f "$TEMP_FILE" "$TEMP_FILE2"' EXIT

# Create an empty file for the ALL_SHADES content
SHADES_FILE=$(mktemp)
if [ $? -ne 0 ]; then
    SHADES_FILE="${CONFIG_DIR}/.shades_temp.$$"
    touch "$SHADES_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to create shades temporary file"
        rm -f "$TEMP_FILE" "$TEMP_FILE2"
        exit 1
    fi
fi
echo "$SHADE_YAML" > "$SHADES_FILE"

# Fix the sed unmatched '|' error by using a different approach
# Replace tokens using compatible sed commands with / as delimiter
cat "$CONFIG_FILE" | sed "s/%%DOCKING_LIGHTS_CODE%%/$DOCKING_LIGHTS_CODE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%AWNING_LIGHTS%%/$AWNING_LIGHTS/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%VENT_FAN1%%/$VENT_FAN1/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%VENT_FAN2%%/$VENT_FAN2/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%EXTERIOR_ACCENT_LIGHTS%%/$EXTERIOR_ACCENT_LIGHTS/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%OPTIMISTIC_MODE%%/$OPTIMISTIC_MODE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

# Replace shade tokens
echo "Replacing shade tokens..."
for token in $ALL_SHADE_TOKENS; do
    token_var="${token}_CODE"
    token_value=$(eval echo \$$token_var)
    token_name="%%${token_var}%%"
    # Use a safer sed approach that should work regardless of content
    sed "s/%%${token_var}%%/${token_value}/g" "$CONFIG_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_FILE"
done

# Replace %%ALL_SHADES%% with the generated shade YAML
echo "Inserting shade YAML entries..."
if grep -q "%%ALL_SHADES%%" "$CONFIG_FILE"; then
    # Use awk for safer multi-line replacement
    awk -v shadefile="$SHADES_FILE" '
    /%%ALL_SHADES%%/ {
        system("cat " shadefile)
        next
    }
    { print }
    ' "$CONFIG_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_FILE"
    echo "Added window shade entries to configuration"
else
    echo "Warning: %%ALL_SHADES%% token not found in $CONFIG_FILE"
fi

# Clean up
rm -f "$SHADES_FILE"

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
echo "Window shade entries have been added with actual numeric codes:"
for token in $ALL_SHADE_TOKENS; do
    # Get the appropriate code based on model year
    code_var="${MODEL_PREFIX}_${token}"
    code=$(eval echo \$$code_var)
    name=$(eval echo \$NAME_$token)
    
    if [ -n "$code" ] && [ -n "$name" ]; then
        echo "  $name: $code"
    fi
done
echo ""
echo "To apply these changes:"
echo "1. Restart Home Assistant"
echo "2. Check that all window shades are functioning correctly"
