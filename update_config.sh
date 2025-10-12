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
MODEL_YEAR_FILE="${CONFIG_DIR}/coach_model_year.txt"

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

# Persist the selected model year for other tooling/hooks
if [ -n "$MODEL_YEAR" ]; then
    if echo "$MODEL_YEAR" > "$MODEL_YEAR_FILE" 2>/dev/null; then
        echo "Model year written to $MODEL_YEAR_FILE"
    else
        echo "Warning: Failed to write model year to $MODEL_YEAR_FILE"
    fi
fi

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
NAME_DS_LIVING_DAY="D/S Living Room Day"; UID_DS_LIVING_DAY="d_s_living_room_day"
NAME_BEDROOM_DRESSER_DAY="Bedroom Dresser Day"; UID_BEDROOM_DRESSER_DAY="bedroom_dresser_day"
NAME_BOTTOM_BUNK_NIGHT="Bottom Bunk Night"; UID_BOTTOM_BUNK_NIGHT="bottom_bunk_night"
NAME_DS_LIVING_NIGHT="D/S Living Room Night"; UID_DS_LIVING_NIGHT="d_s_living_room_night"
NAME_BEDROOM_DRESSER_NIGHT="Bedroom Dresser Night"; UID_BEDROOM_DRESSER_NIGHT="bedroom_dresser_night"
NAME_BEDROOM_FRONT_DAY="Bedroom Front Day"; UID_BEDROOM_FRONT_DAY="bedroom_front_day"
NAME_BEDROOM_REAR_DAY="Bedroom Rear Day"; UID_BEDROOM_REAR_DAY="bedroom_rear_day"
NAME_BEDROOM_FRONT_NIGHT="Bedroom Front Night"; UID_BEDROOM_FRONT_NIGHT="bedroom_front_night"
NAME_BEDROOM_REAR_NIGHT="Bedroom Rear Night"; UID_BEDROOM_REAR_NIGHT="bedroom_rear_night"
NAME_KITCHEN_DAY="Kitchen Day"; UID_KITCHEN_DAY="kitchen_day"
NAME_KITCHEN_NIGHT="Kitchen Night"; UID_KITCHEN_NIGHT="kitchen_night"
NAME_DS_WINDOW1_DAY="D/S Window 1 Day"; UID_DS_WINDOW1_DAY="d_s_window_1_day"
NAME_DS_WINDOW2_DAY="D/S Window 2 Day"; UID_DS_WINDOW2_DAY="d_s_window_2_day"
NAME_DS_WINDOW1_NIGHT="D/S Window 1 Night"; UID_DS_WINDOW1_NIGHT="d_s_window_1_night"
NAME_DS_WINDOW2_NIGHT="D/S Window 2 Night"; UID_DS_WINDOW2_NIGHT="d_s_window_2_night"

NAME_UNDER_SLIDE_LIGHTS_1="Under Slide Lights 1"; UID_UNDER_SLIDE_LIGHTS_1="under_slide_lights_1"
NAME_UNDER_SLIDE_LIGHTS_2="Under Slide Lights 2"; UID_UNDER_SLIDE_LIGHTS_2="under_slide_lights_2"
NAME_PORCH_LIGHT="Porch Light"; UID_PORCH_LIGHT="porch_light"

# Define all shade tokens (used for looping)
ALL_SHADE_TOKENS="WINDSHIELD_DAY DRIVER_DAY PASSENGER_DAY ENTRY_DOOR_DAY WINDSHIELD_NIGHT DRIVER_NIGHT PASSENGER_NIGHT ENTRY_DOOR_NIGHT DINETTE_DAY MID_BATH_NIGHT DINETTE_NIGHT REAR_BATH_NIGHT TOP_BUNK_NIGHT DS_LIVING_DAY BEDROOM_DRESSER_DAY BOTTOM_BUNK_NIGHT DS_LIVING_NIGHT BEDROOM_DRESSER_NIGHT BEDROOM_FRONT_DAY BEDROOM_REAR_DAY BEDROOM_FRONT_NIGHT BEDROOM_REAR_NIGHT KITCHEN_DAY KITCHEN_NIGHT DS_WINDOW1_DAY DS_WINDOW2_DAY DS_WINDOW1_NIGHT DS_WINDOW2_NIGHT"
# Shade configurations for different model years
# 2023+ Model codes
CODE_2023_WINDSHIELD_DAY="73" 
CODE_2023_DRIVER_DAY="75"
CODE_2023_PASSENGER_DAY="77"
CODE_2023_WINDSHIELD_NIGHT="81"
CODE_2023_DRIVER_NIGHT="83"
CODE_2023_PASSENGER_NIGHT="85"
CODE_2023_ENTRY_DOOR_NIGHT="87"
CODE_2023_DINETTE_DAY="89"
CODE_2023_DINETTE_NIGHT="97"
CODE_2023_MID_BATH_NIGHT="95"
CODE_2023_REAR_BATH_NIGHT="103"
CODE_2023_BEDROOM_DRESSER_DAY="107"
CODE_2023_DS_LIVING_NIGHT="99"
CODE_2023_DS_LIVING_DAY="91"
CODE_2023_BEDROOM_DRESSER_NIGHT="115"
CODE_2023_BEDROOM_FRONT_DAY="109" 
CODE_2023_BEDROOM_REAR_DAY="111"
CODE_2023_BEDROOM_FRONT_NIGHT="117" 
CODE_2023_BEDROOM_REAR_NIGHT="119"
#CODE_2023_ENTRY_DOOR_DAY="4"
CODE_2023_BOTTOM_BUNK_NIGHT="21"
CODE_2023_TOP_BUNK_NIGHT="17"
CODE_2023_KITCHEN_DAY="121"
CODE_2023_KITCHEN_NIGHT="129"
CODE_2023_DS_WINDOW1_DAY="93"
CODE_2023_DS_WINDOW2_DAY="105"
CODE_2023_DS_WINDOW1_NIGHT="101"
CODE_2023_DS_WINDOW2_NIGHT="113"
CODE_2023_UNDER_SLIDE_LIGHTS_1="35"
CODE_2023_UNDER_SLIDE_LIGHTS_2="36"
CODE_2023_PORCH_LIGHT="46"


# 2020-2022 Model codes (same as 2023+ in this case, but kept separate for possible future differences)
CODE_2020_WINDSHIELD_DAY="1"
CODE_2020_DRIVER_DAY="2"
CODE_2020_PASSENGER_DAY="81"
CODE_2020_ENTRY_DOOR_DAY="4"
CODE_2020_WINDSHIELD_NIGHT="5"
CODE_2020_DRIVER_NIGHT="6"
CODE_2020_PASSENGER_NIGHT="7"
CODE_2020_ENTRY_DOOR_NIGHT="8"
CODE_2020_DINETTE_DAY="9"
CODE_2020_MID_BATH_NIGHT="12"
CODE_2020_DINETTE_NIGHT="13"
CODE_2020_REAR_BATH_NIGHT="16"
CODE_2020_TOP_BUNK_NIGHT="17"
CODE_2020_DS_LIVING_DAY="10"
CODE_2020_BEDROOM_DRESSER_DAY="20"
CODE_2020_BOTTOM_BUNK_NIGHT="21"
CODE_2020_DS_LIVING_NIGHT="18"
CODE_2020_BEDROOM_DRESSER_NIGHT="24"
CODE_2020_BEDROOM_FRONT_DAY="20"
CODE_2020_BEDROOM_REAR_DAY="20"
CODE_2020_BEDROOM_FRONT_NIGHT="23"
CODE_2020_BEDROOM_REAR_NIGHT="23"
#CODE_2020_UNDER_SLIDE_LIGHTS="127"
CODE_2020_PORCH_LIGHT="71"

# 2017-2019 Model codes
CODE_2017_WINDSHIELD_DAY="1"
CODE_2017_DRIVER_DAY="2"
CODE_2017_PASSENGER_DAY="3"
CODE_2017_ENTRY_DOOR_DAY="4"
CODE_2017_WINDSHIELD_NIGHT="5"
CODE_2017_DRIVER_NIGHT="6"
CODE_2017_PASSENGER_NIGHT="7"
CODE_2017_ENTRY_DOOR_NIGHT="8"
CODE_2017_DINETTE_DAY="10"
CODE_2017_MID_BATH_NIGHT="12"
CODE_2017_DINETTE_NIGHT="14"
CODE_2017_FRONT_SLIDE_NIGHT="15"
CODE_2017_REAR_BATH_NIGHT="16"
CODE_2017_TOP_BUNK_NIGHT="17"
CODE_2017_DS_LIVING_DAY="18"
CODE_2017_BEDROOM_DRESSER_DAY="20"
CODE_2017_BOTTOM_BUNK_NIGHT="21"
CODE_2017_DS_LIVING_NIGHT="22"
CODE_2017_BEDROOM_DRESSER_NIGHT="24"
CODE_2017_BEDROOM_FRONT_DAY="25"
CODE_2017_BEDROOM_REAR_DAY="27"
CODE_2017_BEDROOM_FRONT_NIGHT="29"
CODE_2017_BEDROOM_REAR_NIGHT="31"
#CODE_2017_UNDER_SLIDE_LIGHTS="127"
CODE_2017_PORCH_LIGHT="127"

# Pre-2016 Model codes (copied from PRE2020/2017-2019 for now)
CODE_PRE2016_WINDSHIELD_DAY="1"
CODE_PRE2016_DRIVER_DAY="2"
CODE_PRE2016_PASSENGER_DAY="3"
CODE_PRE2016_ENTRY_DOOR_DAY="4"
CODE_PRE2016_WINDSHIELD_NIGHT="5"
CODE_PRE2016_DRIVER_NIGHT="6"
CODE_PRE2016_PASSENGER_NIGHT="7"
CODE_PRE2016_ENTRY_DOOR_NIGHT="8"
CODE_PRE2016_DINETTE_DAY="10"
CODE_PRE2016_MID_BATH_NIGHT="12"
CODE_PRE2016_DINETTE_NIGHT="14"
CODE_PRE2016_FRONT_SLIDE_NIGHT="15"
CODE_PRE2016_REAR_BATH_NIGHT="16"
CODE_PRE2016_TOP_BUNK_NIGHT="17"
CODE_PRE2016_DS_LIVING_DAY="18"
CODE_PRE2016_BEDROOM_DRESSER_DAY="20"
CODE_PRE2016_BOTTOM_BUNK_NIGHT="21"
CODE_PRE2016_DS_LIVING_NIGHT="22"
CODE_PRE2016_BEDROOM_DRESSER_NIGHT="24"
CODE_PRE2016_BEDROOM_FRONT_DAY="25"
CODE_PRE2016_BEDROOM_REAR_DAY="27"
CODE_PRE2016_BEDROOM_FRONT_NIGHT="29"
CODE_PRE2016_BEDROOM_REAR_NIGHT="31"
#CODE_PRE2016_UNDER_SLIDE_LIGHTS="127"
CODE_PRE2016_PORCH_LIGHT="127"

# Create shade groups YAML with only available shades for the current model year
create_shade_groups_yaml() {
    local PREFIX="$1"
    local GROUPS_FILE="$2"
    
    # Initialize arrays for day and night shades
    day_shades=()
    night_shades=()
    
    # Populate arrays with available shades for this model year
    for token in $ALL_SHADE_TOKENS; do
        code_var="${PREFIX}_${token}"
        code=$(eval echo \$$code_var)
        if [ -n "$code" ]; then
            uid=$(eval echo \$UID_$token)
            # Sort into day and night groups
            if [[ "$token" == *"_DAY" ]]; then
                day_shades+=("cover.$uid")
            elif [[ "$token" == *"_NIGHT" ]]; then
                night_shades+=("cover.$uid")
            fi
        fi
    done
    
    # Start the groups file - generate platform section for template insertion
    echo "  - platform: template" > "$GROUPS_FILE"
    echo "    covers:" >> "$GROUPS_FILE"
    
    # Create all_day_shades group if we have day shades
    if [ ${#day_shades[@]} -gt 0 ]; then
        echo "      all_day_shades:" >> "$GROUPS_FILE"
        echo "        friendly_name: \"All Day Shades\"" >> "$GROUPS_FILE"
        echo "        unique_id: \"all_day_shades\"" >> "$GROUPS_FILE"
        echo "        device_class: shade" >> "$GROUPS_FILE"
        echo "        position_template: >" >> "$GROUPS_FILE"
        echo "          {% set covers = [" >> "$GROUPS_FILE"
        
        # Add each available day shade entity
        for i in "${!day_shades[@]}"; do
            if [ $i -lt $((${#day_shades[@]} - 1)) ]; then
                echo "            '${day_shades[$i]}'," >> "$GROUPS_FILE"
            else
                echo "            '${day_shades[$i]}'" >> "$GROUPS_FILE"
            fi
        done
        
        # Add the template logic
        echo "          ] %}" >> "$GROUPS_FILE"
        echo "          {% set open = covers | selectattr('state', 'equalto', 'open') | list | count %}" >> "$GROUPS_FILE"
        echo "          {% set closed = covers | selectattr('state', 'equalto', 'closed') | list | count %}" >> "$GROUPS_FILE"
        echo "          " >> "$GROUPS_FILE"
        echo "          {% if open == covers | count %}" >> "$GROUPS_FILE"
        echo "            100" >> "$GROUPS_FILE"
        echo "          {% elif closed == covers | count %}" >> "$GROUPS_FILE"
        echo "            0" >> "$GROUPS_FILE"
        echo "          {% else %}" >> "$GROUPS_FILE"
        echo "            50" >> "$GROUPS_FILE"
        echo "          {% endif %}" >> "$GROUPS_FILE"
        
        # Add open_cover service - always available
        echo "        open_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.open_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available day shade entity to service call
        for shade in "${day_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add close_cover service - always available
        echo "        close_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.close_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available day shade entity to service call
        for shade in "${day_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add device class to ensure both open/close are always available
        echo "        device_class: shade" >> "$GROUPS_FILE"
        
        # Add spacing for next group
        echo "" >> "$GROUPS_FILE"
    fi
    
    # Create cockpit_day_shades group
    # Check if entry_door_day code is defined for this model year
    entry_door_day_code=$(eval echo \$${PREFIX}_ENTRY_DOOR_DAY)
    
    echo "      cockpit_day_shades:" >> "$GROUPS_FILE"
    echo "        friendly_name: \"Cockpit Day Shades\"" >> "$GROUPS_FILE"
    echo "        unique_id: \"cockpit_day_shades\"" >> "$GROUPS_FILE"
    echo "        device_class: shade" >> "$GROUPS_FILE"
    echo "        position_template: >" >> "$GROUPS_FILE"
    
    # Start with base covers common to all models
    echo "          {% set covers = [" >> "$GROUPS_FILE"
    echo "            states.cover.windshield_day," >> "$GROUPS_FILE"
    echo "            states.cover.driver_day," >> "$GROUPS_FILE"
    echo "            states.cover.passenger_day" >> "$GROUPS_FILE"
    
    # Conditionally add entry_door_day to the template if it exists for this model year
    if [ -n "$entry_door_day_code" ]; then
        echo "            ,states.cover.entry_door_day" >> "$GROUPS_FILE"
    fi
    
    echo "          ] %}" >> "$GROUPS_FILE"
    echo "          {% set open = covers | selectattr('state', 'equalto', 'open') | list | count %}" >> "$GROUPS_FILE"
    echo "          {% set closed = covers | selectattr('state', 'equalto', 'closed') | list | count %}" >> "$GROUPS_FILE"
    echo "          {% if open == covers | count %}" >> "$GROUPS_FILE"
    echo "            100" >> "$GROUPS_FILE"
    echo "          {% elif closed == covers | count %}" >> "$GROUPS_FILE"
    echo "            0" >> "$GROUPS_FILE"
    echo "          {% else %}" >> "$GROUPS_FILE"
    echo "            50" >> "$GROUPS_FILE"
    echo "          {% endif %}" >> "$GROUPS_FILE"
    
    # Add open_cover service
    echo "        open_cover:" >> "$GROUPS_FILE"
    echo "          service: cover.open_cover" >> "$GROUPS_FILE"
    echo "          target:" >> "$GROUPS_FILE"
    echo "            entity_id:" >> "$GROUPS_FILE"
    echo "              - cover.windshield_day" >> "$GROUPS_FILE"
    echo "              - cover.driver_day" >> "$GROUPS_FILE"
    echo "              - cover.passenger_day" >> "$GROUPS_FILE"
    
    # Only include entry_door_day in service calls if it's defined for this model
    if [ -n "$entry_door_day_code" ]; then
        echo "              - cover.entry_door_day" >> "$GROUPS_FILE"
    fi
    
    # Add close_cover service
    echo "        close_cover:" >> "$GROUPS_FILE"
    echo "          service: cover.close_cover" >> "$GROUPS_FILE"
    echo "          target:" >> "$GROUPS_FILE"
    echo "            entity_id:" >> "$GROUPS_FILE"
    echo "              - cover.windshield_day" >> "$GROUPS_FILE"
    echo "              - cover.driver_day" >> "$GROUPS_FILE"
    echo "              - cover.passenger_day" >> "$GROUPS_FILE"
    
    # Only include entry_door_day in service calls if it's defined for this model
    if [ -n "$entry_door_day_code" ]; then
        echo "              - cover.entry_door_day" >> "$GROUPS_FILE"
    fi
    
    echo "" >> "$GROUPS_FILE"
    
    # Create all_night_shades group if we have night shades
    if [ ${#night_shades[@]} -gt 0 ]; then
        echo "      all_night_shades:" >> "$GROUPS_FILE"
        echo "        friendly_name: \"All Night Shades\"" >> "$GROUPS_FILE"
        echo "        unique_id: \"all_night_shades\"" >> "$GROUPS_FILE"
        echo "        device_class: shade" >> "$GROUPS_FILE"
        echo "        position_template: >" >> "$GROUPS_FILE"
        echo "          {% set covers = [" >> "$GROUPS_FILE"
        
        # Add each available night shade entity
        for i in "${!night_shades[@]}"; do
            if [ $i -lt $((${#night_shades[@]} - 1)) ]; then
                echo "            '${night_shades[$i]}'," >> "$GROUPS_FILE"
            else
                echo "            '${night_shades[$i]}'" >> "$GROUPS_FILE"
            fi
        done
        
        # Add the template logic
        echo "          ] %}" >> "$GROUPS_FILE"
        echo "          {% set open = covers | selectattr('state', 'equalto', 'open') | list | count %}" >> "$GROUPS_FILE"
        echo "          {% set closed = covers | selectattr('state', 'equalto', 'closed') | list | count %}" >> "$GROUPS_FILE"
        echo "          " >> "$GROUPS_FILE"
        echo "          {% if open == covers | count %}" >> "$GROUPS_FILE"
        echo "            100" >> "$GROUPS_FILE"
        echo "          {% elif closed == covers | count %}" >> "$GROUPS_FILE"
        echo "            0" >> "$GROUPS_FILE"
        echo "          {% else %}" >> "$GROUPS_FILE"
        echo "            50" >> "$GROUPS_FILE"
        echo "          {% endif %}" >> "$GROUPS_FILE"
        
        # Add open_cover service
        echo "        open_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.open_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available night shade entity to service call
        for shade in "${night_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add close_cover service
        echo "        close_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.close_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available night shade entity to service call
        for shade in "${night_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add device class to ensure both open/close are always available
        echo "        device_class: shade" >> "$GROUPS_FILE"
    fi
    
    # Create ds_so_day_shades group (Driver Side - Street Side Day Shades)
    # This group includes DS_LIVING_DAY (always exists) and optionally DS_WINDOW1_DAY, DS_WINDOW2_DAY
    ds_so_day_shades=()
    
    # DS_LIVING_DAY always exists - check using the same pattern as other shades
    ds_living_day_code=$(eval echo \$${PREFIX}_DS_LIVING_DAY)
    if [ -n "$ds_living_day_code" ]; then
        ds_so_day_shades+=("cover.$UID_DS_LIVING_DAY")
    fi
    
    # Add DS_WINDOW1_DAY if it exists for this model year
    ds_window1_day_code=$(eval echo \$${PREFIX}_DS_WINDOW1_DAY)
    if [ -n "$ds_window1_day_code" ]; then
        ds_so_day_shades+=("cover.$UID_DS_WINDOW1_DAY")
    fi
    
    # Add DS_WINDOW2_DAY if it exists for this model year
    ds_window2_day_code=$(eval echo \$${PREFIX}_DS_WINDOW2_DAY)
    if [ -n "$ds_window2_day_code" ]; then
        ds_so_day_shades+=("cover.$UID_DS_WINDOW2_DAY")
    fi
    
    # Create the group if we have any shades
    if [ ${#ds_so_day_shades[@]} -gt 0 ]; then
        echo "      ds_so_day_shades:" >> "$GROUPS_FILE"
        echo "        friendly_name: \"Driver Side Day Shades\"" >> "$GROUPS_FILE"
        echo "        unique_id: \"ds_so_day_shades\"" >> "$GROUPS_FILE"
        echo "        device_class: shade" >> "$GROUPS_FILE"
        echo "        position_template: >" >> "$GROUPS_FILE"
        echo "          {% set covers = [" >> "$GROUPS_FILE"
        
        # Add each available DS day shade entity
        for i in "${!ds_so_day_shades[@]}"; do
            if [ $i -lt $((${#ds_so_day_shades[@]} - 1)) ]; then
                echo "            states.cover.${ds_so_day_shades[$i]#cover.}," >> "$GROUPS_FILE"
            else
                echo "            states.cover.${ds_so_day_shades[$i]#cover.}" >> "$GROUPS_FILE"
            fi
        done
        
        # Add the template logic (matching the existing all_night_shades pattern)
        echo "          ] %}" >> "$GROUPS_FILE"
        echo "          {% set open = covers | selectattr('state', 'equalto', 'open') | list | count %}" >> "$GROUPS_FILE"
        echo "          {% set closed = covers | selectattr('state', 'equalto', 'closed') | list | count %}" >> "$GROUPS_FILE"
        echo "          " >> "$GROUPS_FILE"
        echo "          {% if open == covers | count %}" >> "$GROUPS_FILE"
        echo "            100" >> "$GROUPS_FILE"
        echo "          {% elif closed == covers | count %}" >> "$GROUPS_FILE"
        echo "            0" >> "$GROUPS_FILE"
        echo "          {% else %}" >> "$GROUPS_FILE"
        echo "            50" >> "$GROUPS_FILE"
        echo "          {% endif %}" >> "$GROUPS_FILE"
        
        # Add open_cover service
        echo "        open_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.open_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available DS day shade entity to service call
        for shade in "${ds_so_day_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add close_cover service
        echo "        close_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.close_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available DS day shade entity to service call
        for shade in "${ds_so_day_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
    fi
    
    # Create ds_so_night_shades group (Driver Side - Street Side Night Shades)
    # This group includes DS_LIVING_NIGHT (always exists) and optionally DS_WINDOW1_NIGHT, DS_WINDOW2_NIGHT
    ds_so_night_shades=()
    
    # DS_LIVING_NIGHT always exists - check using the same pattern as other shades
    ds_living_night_code=$(eval echo \$${PREFIX}_DS_LIVING_NIGHT)
    if [ -n "$ds_living_night_code" ]; then
        ds_so_night_shades+=("cover.$UID_DS_LIVING_NIGHT")
    fi
    
    # Add DS_WINDOW1_NIGHT if it exists for this model year
    ds_window1_night_code=$(eval echo \$${PREFIX}_DS_WINDOW1_NIGHT)
    if [ -n "$ds_window1_night_code" ]; then
        ds_so_night_shades+=("cover.$UID_DS_WINDOW1_NIGHT")
    fi
    
    # Add DS_WINDOW2_NIGHT if it exists for this model year
    ds_window2_night_code=$(eval echo \$${PREFIX}_DS_WINDOW2_NIGHT)
    if [ -n "$ds_window2_night_code" ]; then
        ds_so_night_shades+=("cover.$UID_DS_WINDOW2_NIGHT")
    fi
    
    # Create the group if we have any shades
    if [ ${#ds_so_night_shades[@]} -gt 0 ]; then
        echo "      ds_so_night_shades:" >> "$GROUPS_FILE"
        echo "        friendly_name: \"Driver Side Night Shades\"" >> "$GROUPS_FILE"
        echo "        unique_id: \"ds_so_night_shades\"" >> "$GROUPS_FILE"
        echo "        device_class: shade" >> "$GROUPS_FILE"
        echo "        position_template: >" >> "$GROUPS_FILE"
        echo "          {% set covers = [" >> "$GROUPS_FILE"
        
        # Add each available DS night shade entity
        for i in "${!ds_so_night_shades[@]}"; do
            if [ $i -lt $((${#ds_so_night_shades[@]} - 1)) ]; then
                echo "            states.cover.${ds_so_night_shades[$i]#cover.}," >> "$GROUPS_FILE"
            else
                echo "            states.cover.${ds_so_night_shades[$i]#cover.}" >> "$GROUPS_FILE"
            fi
        done
        
        # Add the template logic (matching the existing all_night_shades pattern)
        echo "          ] %}" >> "$GROUPS_FILE"
        echo "          {% set open = covers | selectattr('state', 'equalto', 'open') | list | count %}" >> "$GROUPS_FILE"
        echo "          {% set closed = covers | selectattr('state', 'equalto', 'closed') | list | count %}" >> "$GROUPS_FILE"
        echo "          " >> "$GROUPS_FILE"
        echo "          {% if open == covers | count %}" >> "$GROUPS_FILE"
        echo "            100" >> "$GROUPS_FILE"
        echo "          {% elif closed == covers | count %}" >> "$GROUPS_FILE"
        echo "            0" >> "$GROUPS_FILE"
        echo "          {% else %}" >> "$GROUPS_FILE"
        echo "            50" >> "$GROUPS_FILE"
        echo "          {% endif %}" >> "$GROUPS_FILE"
        
        # Add open_cover service
        echo "        open_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.open_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available DS night shade entity to service call
        for shade in "${ds_so_night_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
        
        # Add close_cover service
        echo "        close_cover:" >> "$GROUPS_FILE"
        echo "          service: cover.close_cover" >> "$GROUPS_FILE"
        echo "          target:" >> "$GROUPS_FILE"
        echo "            entity_id:" >> "$GROUPS_FILE"
        
        # Add each available DS night shade entity to service call
        for shade in "${ds_so_night_shades[@]}"; do
            echo "              - $shade" >> "$GROUPS_FILE"
        done
    fi
    
    # Report what we created
    echo "Created shade group configurations with ${#day_shades[@]} day shades, ${#night_shades[@]} night shades, ${#ds_so_day_shades[@]} DS day shades, and ${#ds_so_night_shades[@]} DS night shades."
    
    # Debug output for DS day shades
    if [ ${#ds_so_day_shades[@]} -gt 0 ]; then
        echo "DS day shades included:"
        for shade in "${ds_so_day_shades[@]}"; do
            echo "  - $shade"
        done
    else
        echo "No DS day shades found for this model year"
    fi
    
    # Debug output for DS night shades
    if [ ${#ds_so_night_shades[@]} -gt 0 ]; then
        echo "DS night shades included:"
        for shade in "${ds_so_night_shades[@]}"; do
            echo "  - $shade"
        done
    else
        echo "No DS night shades found for this model year"
    fi
}

# Create the YAML entries one line at a time instead of using a single string
create_shade_yaml() {
    local PREFIX="$1"
    local SHADE_FILE="$2"
    
    # Add header
    echo "    # Window shade configurations for model year $MODEL_YEAR" > "$SHADE_FILE"
    
    # Process each shade
    for token in $ALL_SHADE_TOKENS; do
        code_var="${PREFIX}_${token}"
        code=$(eval echo \$$code_var)
        if [ -n "$code" ]; then
            name=$(eval echo \$NAME_$token)
            uid=$(eval echo \$UID_$token)
            
            # Add spacing between entries (except before the first one)
            if [ $(wc -l < "$SHADE_FILE") -gt 1 ]; then
                echo "" >> "$SHADE_FILE"
                echo "" >> "$SHADE_FILE"
            fi
            
            # Add the shade entry line by line
            echo "    # Shade configuration for $name (code: $code)" >> "$SHADE_FILE"
            echo "    - name: \"$name\"" >> "$SHADE_FILE"
            echo "      unique_id: \"$uid\"" >> "$SHADE_FILE"
            echo "      state_topic: \"RVC/WINDOW_SHADE_CONTROL_STATUS/$code\"" >> "$SHADE_FILE"
            echo "      position_topic: \"RVC/WINDOW_SHADE_CONTROL_STATUS/$code\"" >> "$SHADE_FILE"
            echo "      value_template: >-" >> "$SHADE_FILE"
            echo "        {% if not value_json is defined %}closed" >> "$SHADE_FILE"
            echo "        {% else %}" >> "$SHADE_FILE"
            echo "        {% set motor = value_json['motor status definition'] | default('inactive') %}" >> "$SHADE_FILE"
            echo "        {% set last_cmd = value_json['last command definition'] | default('none') %}" >> "$SHADE_FILE"
            echo "        {% if motor == 'active' %}" >> "$SHADE_FILE"
            echo "          {% if last_cmd == 'toggle forward' %}opening" >> "$SHADE_FILE"
            echo "          {% elif last_cmd == 'toggle reverse' %}closing" >> "$SHADE_FILE"
            echo "          {% else %}closed{% endif %}" >> "$SHADE_FILE"
            echo "        {% else %}" >> "$SHADE_FILE"
            echo "          {% if last_cmd == 'toggle forward' %}open" >> "$SHADE_FILE"
            echo "          {% elif last_cmd == 'toggle reverse' %}closed" >> "$SHADE_FILE"
            echo "          {% else %}closed{% endif %}" >> "$SHADE_FILE"
            echo "        {% endif %}" >> "$SHADE_FILE"
            echo "        {% endif %}" >> "$SHADE_FILE"
            echo "      command_topic: \"RVC/WINDOW_SHADE_CONTROL_COMMAND/$code/set\"" >> "$SHADE_FILE"
            echo "      payload_open: '{\"instance\": $code, \"command\": \"open\"}'" >> "$SHADE_FILE"
            echo "      payload_close: '{\"instance\": $code, \"command\": \"close\"}'" >> "$SHADE_FILE"
            echo "      payload_stop: '{\"instance\": $code, \"command\": \"stop\"}'" >> "$SHADE_FILE"
            echo "      payload_available: \"online\"" >> "$SHADE_FILE"
            echo "      payload_not_available: \"offline\"" >> "$SHADE_FILE"
            echo "      state_opening: \"opening\"" >> "$SHADE_FILE"
            echo "      state_closing: \"closing\"" >> "$SHADE_FILE"
            echo "      state_open: \"open\"" >> "$SHADE_FILE"
            echo "      state_closed: \"closed\"" >> "$SHADE_FILE"
            echo "      position_template: >-" >> "$SHADE_FILE"
            echo "        {% set last_cmd = value_json['last command definition'] %}" >> "$SHADE_FILE"
            echo "        {% if last_cmd == 'toggle forward' %}" >> "$SHADE_FILE"
            echo "        100" >> "$SHADE_FILE"
            echo "        {% elif last_cmd == 'toggle reverse' %}" >> "$SHADE_FILE"
            echo "        0" >> "$SHADE_FILE"
            echo "        {% else %}" >> "$SHADE_FILE"
            echo "        {{ value_json.position | default(value_json['motor duty']) | default(0) }}" >> "$SHADE_FILE"
            echo "        {% endif %}" >> "$SHADE_FILE"
            echo "      position_open: 100" >> "$SHADE_FILE"
            echo "      position_closed: 0" >> "$SHADE_FILE"
            echo "      #set_position_topic: \"RVC/WINDOW_SHADE_CONTROL_COMMAND/$code/set\"" >> "$SHADE_FILE"
            echo "      #set_position_template: '{\"instance\": $code, \"position\": {{ position }}}'" >> "$SHADE_FILE"
            echo "      availability_template: >-" >> "$SHADE_FILE"
            echo "        {% if value_json is defined and value_json['motor status definition'] is defined %}" >> "$SHADE_FILE"
            echo "        online" >> "$SHADE_FILE"
            echo "        {% else %}" >> "$SHADE_FILE"
            echo "        offline" >> "$SHADE_FILE"
            echo "        {% endif %}" >> "$SHADE_FILE"
            echo "      optimistic: false" >> "$SHADE_FILE"
            # Add an extra blank line at the end of each shade entry
            echo "" >> "$SHADE_FILE"
        fi
    done
    
    echo "Created shade YAML entries for $(grep -c "^    - name:" "$SHADE_FILE") shades."
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
    PORCH_LIGHT_VALUE="$CODE_2023_PORCH_LIGHT"
    UNDER_SLIDE_LIGHTS_1_VALUE="$CODE_2023_UNDER_SLIDE_LIGHTS_1"
    UNDER_SLIDE_LIGHTS_2_VALUE="$CODE_2023_UNDER_SLIDE_LIGHTS_2"
    VENT_FAN_1="1"
    VENT_FAN_2="2"
    OPTIMISTIC_MODE="true"
    EXTERNAL_TEMP="249"
    INDOOR_TEMP="248"
    LIGHT_COMMAND_ON="0"
    LIGHT_COMMAND_OFF="3"
    # Thermostat instances
    THERMOSTAT1="7"
    THERMOSTAT2="8"
    THERMOSTAT3="9"
    THERMOSTAT4="167"
    # Thermostat ambient instances (same for all model years)
    THERMOSTAT1_AMBIENT="7"
    THERMOSTAT2_AMBIENT="9"
    THERMOSTAT3_AMBIENT="8"
    THERMOSTAT4_AMBIENT="248"
    # Set shade codes
    set_shade_tokens "CODE_2023"
}

# 2020-2022 Model configurations
configure_2020_to_2022() {
    # General device codes
    DOCKING_LIGHTS_CODE="43"
    AWNING_LIGHTS="66"
    EXTERIOR_ACCENT_LIGHTS="67"
    PORCH_LIGHT_VALUE="$CODE_2020_PORCH_LIGHT"
    UNDER_SLIDE_LIGHTS_1_VALUE="" # Not defined for 2020-2022
    UNDER_SLIDE_LIGHTS_2_VALUE="" # Not defined for 2020-2022
    VENT_FAN_1="55"
    VENT_FAN_2="56"
    OPTIMISTIC_MODE="true"
    EXTERNAL_TEMP="249"
    INDOOR_TEMP="250"
    LIGHT_COMMAND_ON="0"
    LIGHT_COMMAND_OFF="3"
    # Thermostat instances
    THERMOSTAT1="164"
    THERMOSTAT2="165"
    THERMOSTAT3="166"
    THERMOSTAT4="167"
    # Thermostat ambient instances (same for all model years)
    THERMOSTAT1_AMBIENT="249"
    THERMOSTAT2_AMBIENT="249"
    THERMOSTAT3_AMBIENT="250"
    THERMOSTAT4_AMBIENT="250"
    # Set shade codes
    set_shade_tokens "CODE_2020"
}

# 2017-2019 Model configurations
configure_2017_to_2019() {
    # General device codes
    DOCKING_LIGHTS_CODE="121"
    AWNING_LIGHTS="122"
    EXTERIOR_ACCENT_LIGHTS="123"
    PORCH_LIGHT_VALUE="$CODE_2017_PORCH_LIGHT"
    UNDER_SLIDE_LIGHTS_1_VALUE="" # Not defined for 2017-2019
    UNDER_SLIDE_LIGHTS_2_VALUE="" # Not defined for 2017-2019
    VENT_FAN_1="55"
    VENT_FAN_2="56"
    OPTIMISTIC_MODE="false"
    EXTERNAL_TEMP="249"
    INDOOR_TEMP="250"
    LIGHT_COMMAND_ON="0"
    LIGHT_COMMAND_OFF="3"
    # Thermostat instances
    THERMOSTAT1="1"
    THERMOSTAT2="2"
    THERMOSTAT3="3"
    THERMOSTAT4="4"
    # Thermostat ambient instances (same for all model years)
    THERMOSTAT1_AMBIENT="249"
    THERMOSTAT2_AMBIENT="249"
    THERMOSTAT3_AMBIENT="250"
    THERMOSTAT4_AMBIENT="250"
    # Set shade codes
    set_shade_tokens "CODE_2017"
}

# Pre-2016 Model configurations
configure_pre_2016() {
    # General device codes (copied from 2017-2019 for now)
    DOCKING_LIGHTS_CODE="121"
    AWNING_LIGHTS="122"
    EXTERIOR_ACCENT_LIGHTS="123"
    PORCH_LIGHT_VALUE="$CODE_PRE2016_PORCH_LIGHT"
    UNDER_SLIDE_LIGHTS_1_VALUE="" # Not defined for Pre-2016
    UNDER_SLIDE_LIGHTS_2_VALUE="" # Not defined for Pre-2016
    VENT_FAN_1="55"
    VENT_FAN_2="56"
    OPTIMISTIC_MODE="false"
    EXTERNAL_TEMP="249"
    INDOOR_TEMP="250"
    LIGHT_COMMAND_ON="0" # Toggle
    LIGHT_COMMAND_OFF="3" # Toggle
    # Thermostat instances
    THERMOSTAT1="1"
    THERMOSTAT2="2"
    THERMOSTAT3="3"
    THERMOSTAT4="4"
    # Thermostat ambient instances (same for all model years)
    THERMOSTAT1_AMBIENT="249"
    THERMOSTAT2_AMBIENT="249"
    THERMOSTAT3_AMBIENT="250"
    THERMOSTAT4_AMBIENT="250"
    # Set shade codes
    set_shade_tokens "CODE_PRE2016"
}

# Apply the appropriate configuration based on model year
if [ "$MODEL_YEAR" -ge 2023 ]; then
    echo "Applying configuration for 2023+ models"
    configure_2023_plus
    MODEL_PREFIX="CODE_2023"
elif [ "$MODEL_YEAR" -ge 2020 ] && [ "$MODEL_YEAR" -le 2022 ]; then
    echo "Applying configuration for 2020-2022 models"
    configure_2020_to_2022
    MODEL_PREFIX="CODE_2020"
elif [ "$MODEL_YEAR" -ge 2017 ] && [ "$MODEL_YEAR" -le 2019 ]; then
    echo "Applying configuration for 2017-2019 models"
    configure_2017_to_2019
    MODEL_PREFIX="CODE_2017"
else
    echo "Applying configuration for Pre-2016 models"
    configure_pre_2016
    MODEL_PREFIX="CODE_PRE2016"
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

# Create temporary files for the shade YAML
SHADES_FILE=$(mktemp)
SHADE_GROUPS_FILE=$(mktemp)
if [ $? -ne 0 ]; then
    SHADES_FILE="${CONFIG_DIR}/.shades_temp.$$"
    SHADE_GROUPS_FILE="${CONFIG_DIR}/.shade_groups_temp.$$"
    touch "$SHADES_FILE" "$SHADE_GROUPS_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to create shades temporary files"
        rm -f "$TEMP_FILE"
        exit 1
    fi
fi

# Trap to clean up temporary files on exit
trap 'rm -f "$TEMP_FILE" "$SHADES_FILE" "$SHADE_GROUPS_FILE"' EXIT

# Create the shade YAML entries and shade groups in the temporary files
create_shade_yaml "$MODEL_PREFIX" "$SHADES_FILE"
create_shade_groups_yaml "$MODEL_PREFIX" "$SHADE_GROUPS_FILE"

# Fix the sed unmatched '|' error by using a different approach
# Replace tokens using compatible sed commands with / as delimiter
cat "$CONFIG_FILE" | sed "s/%%DOCKING_LIGHTS_CODE%%/$DOCKING_LIGHTS_CODE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%AWNING_LIGHTS%%/$AWNING_LIGHTS/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%VENT_FAN_1%%/$VENT_FAN_1/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%VENT_FAN_2%%/$VENT_FAN_2/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%EXTERIOR_ACCENT_LIGHTS%%/$EXTERIOR_ACCENT_LIGHTS/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%PORCH_LIGHT%%/$PORCH_LIGHT_VALUE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%UNDER_SLIDE_LIGHTS_1%%/$UNDER_SLIDE_LIGHTS_1_VALUE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%UNDER_SLIDE_LIGHTS_2%%/$UNDER_SLIDE_LIGHTS_2_VALUE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%OPTIMISTIC_MODE%%/$OPTIMISTIC_MODE/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%EXTERNAL_TEMP%%/$EXTERNAL_TEMP/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%INDOOR_TEMP%%/$INDOOR_TEMP/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%LIGHT_COMMAND_ON%%/$LIGHT_COMMAND_ON/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%LIGHT_COMMAND_OFF%%/$LIGHT_COMMAND_OFF/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

# Replace thermostat tokens
cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT1%%/$THERMOSTAT1/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT2%%/$THERMOSTAT2/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT3%%/$THERMOSTAT3/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT4%%/$THERMOSTAT4/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

# Replace thermostat ambient tokens
cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT1_AMBIENT%%/$THERMOSTAT1_AMBIENT/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT2_AMBIENT%%/$THERMOSTAT2_AMBIENT/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT3_AMBIENT%%/$THERMOSTAT3_AMBIENT/g" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CONFIG_FILE"

cat "$CONFIG_FILE" | sed "s/%%THERMOSTAT4_AMBIENT%%/$THERMOSTAT4_AMBIENT/g" > "$TEMP_FILE"
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

# Replace %%ALL_SHADES%% and %%ALL_SHADE_GROUPS%% with the generated YAML
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

echo "Inserting shade group YAML entries..."
if grep -q "%%ALL_SHADE_GROUPS%%" "$CONFIG_FILE"; then
    # Check if all_night_shades exists in the config file
    if grep -q "all_night_shades:" "$CONFIG_FILE"; then
        echo "Preserving custom all_night_shades template..."
        # Extract the all_night_shades_template
        ALL_NIGHT_SHADES_TEMPLATE=$(awk '/all_night_shades:/,/close_cover:/ {print}' "$CONFIG_FILE" | awk '/close_cover:/,/}/ {print}')
        
        # Use awk for safer multi-line replacement
        awk -v groupsfile="$SHADE_GROUPS_FILE" '
        /%%ALL_SHADE_GROUPS%%/ {
            system("cat " groupsfile)
            next
        }
        { print }
        ' "$CONFIG_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$CONFIG_FILE"
        
        # Re-insert the preserved all_night_shades template if it exists
        if [ -n "$ALL_NIGHT_SHADES_TEMPLATE" ]; then
            echo "Re-inserting preserved all_night_shades template..."
            # Find the template covers section and append the preserved template
            awk -v template="$ALL_NIGHT_SHADES_TEMPLATE" '
            /^  template:/ && in_template == 0 {
                in_template = 1
                print
                next
            }
            /^    covers:/ && in_template == 1 {
                in_covers = 1
                print
                next
            }
            in_covers == 1 && /^[^ ]/ {
                # We are leaving the covers section, insert the template here
                print template
                in_template = 0
                in_covers = 0
                print
                next
            }
            { print }
            END {
                # If we reached the end and still in covers section, append template
                if (in_covers == 1) {
                    print template
                }
            }
            ' "$CONFIG_FILE" > "$TEMP_FILE"
            mv "$TEMP_FILE" "$CONFIG_FILE"
        fi
        
        echo "Added shade group entries to configuration"
    else
        # Use awk for safer multi-line replacement
        awk -v groupsfile="$SHADE_GROUPS_FILE" '
        /%%ALL_SHADE_GROUPS%%/ {
            system("cat " groupsfile)
            next
        }
        { print }
        ' "$CONFIG_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$CONFIG_FILE"
        echo "Added shade group entries to configuration"
    fi
else
    echo "Warning: %%ALL_SHADE_GROUPS%% token not found in $CONFIG_FILE"
fi

echo "==============================================="
echo "Configuration updated for model year $MODEL_YEAR"
echo "==============================================="
echo "Tokens replaced:"
echo ""
echo "General device codes:"
echo "  %%DOCKING_LIGHTS_CODE%% -> $DOCKING_LIGHTS_CODE"
echo "  %%AWNING_LIGHTS%% -> $AWNING_LIGHTS"
echo "  %%EXTERIOR_ACCENT_LIGHTS%% -> $EXTERIOR_ACCENT_LIGHTS"
echo "  %%PORCH_LIGHT%% -> $PORCH_LIGHT_VALUE"
echo "  %%UNDER_SLIDE_LIGHTS_1%% -> $UNDER_SLIDE_LIGHTS_1_VALUE"
echo "  %%UNDER_SLIDE_LIGHTS_2%% -> $UNDER_SLIDE_LIGHTS_2_VALUE"
echo "  %%VENT_FAN_1%% -> $VENT_FAN_1"
echo "  %%VENT_FAN_2%% -> $VENT_FAN_2"
echo "  %%OPTIMISTIC_MODE%% -> $OPTIMISTIC_MODE"
echo "  %%EXTERNAL_TEMP%% -> $EXTERNAL_TEMP"
echo "  %%INDOOR_TEMP%% -> $INDOOR_TEMP"
echo "  %%LIGHT_COMMAND_ON%% -> $LIGHT_COMMAND_ON"
echo "  %%LIGHT_COMMAND_OFF%% -> $LIGHT_COMMAND_OFF"
echo ""
echo "Thermostat instances:"
echo "  %%THERMOSTAT1%% -> $THERMOSTAT1"
echo "  %%THERMOSTAT2%% -> $THERMOSTAT2"
echo "  %%THERMOSTAT3%% -> $THERMOSTAT3"
echo "  %%THERMOSTAT4%% -> $THERMOSTAT4"
echo ""
echo "Thermostat ambient instances:"
echo "  %%THERMOSTAT1_AMBIENT%% -> $THERMOSTAT1_AMBIENT"
echo "  %%THERMOSTAT2_AMBIENT%% -> $THERMOSTAT2_AMBIENT"
echo "  %%THERMOSTAT3_AMBIENT%% -> $THERMOSTAT3_AMBIENT"
echo "  %%THERMOSTAT4_AMBIENT%% -> $THERMOSTAT4_AMBIENT"
echo ""
echo "Window shade entries for model year $MODEL_YEAR:"
echo ""
echo "Included shades (configured in this model year):"
included_count=0
for token in $ALL_SHADE_TOKENS; do
    # Get the appropriate code based on model year
    code_var="${MODEL_PREFIX}_${token}"
    code=$(eval echo \$$code_var)
    name=$(eval echo \$NAME_$token)
    
    if [ -n "$code" ] && [ -n "$name" ]; then
        echo "  $name: $code"
        ((included_count++))
    fi
done

if [ $included_count -eq 0 ]; then
    echo "  (None found)"
fi

echo ""
echo "Excluded shades (not configured for this model year):"
excluded_count=0
for token in $ALL_SHADE_TOKENS; do
    # Get the appropriate code based on model year
    code_var="${MODEL_PREFIX}_${token}"
    code=$(eval echo \$$code_var)
    name=$(eval echo \$NAME_$token)
    
    if [ -z "$code" ] && [ -n "$name" ]; then
        echo "  $name: (not available for this model year)"
        ((excluded_count++))
    fi
done

if [ $excluded_count -eq 0 ]; then
    echo "  (None)"
fi
echo ""
echo "To apply these changes:"
echo "1. Restart Home Assistant"
echo "2. Check that all window shades are functioning correctly"
