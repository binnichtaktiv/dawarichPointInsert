#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== insert dawarich point ===${NC}\n"

echo -e "${YELLOW}select mode:${NC}"
echo "1) add single point"
echo "2) add multiple points - AFTER last tracked point"
echo "3) add multiple points - BEFORE first tracked point"
read -p "choice (1/2/3): " mode

case $mode in
    1)
        mode_name="single"
        ;;
    2)
        mode_name="after"
        ;;
    3)
        mode_name="before"
        ;;
    *)
        echo -e "${RED}invalid choice!${NC}"
        exit 1
        ;;
esac

if [ "$mode_name" != "single" ]; then
    read -p "interval in seconds: " interval
fi


insert_point() {
    local lat=$1
    local lon=$2
    local timestamp=$3
    
    sql_command="INSERT INTO points (latitude, longitude, lonlat, timestamp, battery, altitude, accuracy, velocity, user_id, created_at, updated_at) VALUES (
        $lat,
        $lon,
        ST_SetSRID(ST_MakePoint($lon, $lat), 4326),
        $timestamp,
        100,
        0,
        1,
        0,
        1,
        NOW(),
        NOW()
    );"
    
    docker exec -i dawarich_db psql -U postgres -d dawarich_development -c "$sql_command" > /dev/null 2>&1
    return $?
}

if [ "$mode_name" = "single" ]; then
    echo -e "\n${GREEN}coordinates from google maps:${NC}"
    read -p "format (48.137154, 11.576124): " coords
    
    latitude=$(echo "$coords" | cut -d',' -f1 | xargs)
    longitude=$(echo "$coords" | cut -d',' -f2 | xargs)
    
    echo -e "\n${GREEN}date and time (local time - Europe/Berlin):${NC}"
    read -p "date (DD.MM.YYYY): " date_input
    read -p "time (HH:MM:SS): " time_input
    
    datetime="${date_input} ${time_input}"
    
    echo -e "\n${BLUE}insert point...${NC}"
    
    sql_command="INSERT INTO points (latitude, longitude, lonlat, timestamp, battery, altitude, accuracy, velocity, user_id, created_at, updated_at) VALUES (
        $latitude,
        $longitude,
        ST_SetSRID(ST_MakePoint($longitude, $latitude), 4326),
        EXTRACT(EPOCH FROM (TO_TIMESTAMP('$datetime', 'DD.MM.YYYY HH24:MI:SS') - INTERVAL '1 hour'))::INTEGER,
        100,
        0,
        1,
        0,
        1,
        NOW(),
        NOW()
    );"
    
    docker exec -i dawarich_db psql -U postgres -d dawarich_development -c "$sql_command"
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ point successfully added!${NC}"
        echo -e "  lat: $latitude, lon: $longitude"
        echo -e "  local time: $datetime"
    else
        echo -e "\n${RED}✗ error adding point${NC}"
        exit 1
    fi
    
else
    echo -e "\n${GREEN}first point - date and time (local time - Europe/Berlin):${NC}"
    read -p "date (DD.MM.YYYY): " date_input
    read -p "time (HH:MM:SS): " time_input
    
    datetime="${date_input} ${time_input}"
    
    base_timestamp=$(docker exec -i dawarich_db psql -U postgres -d dawarich_development -t -c "SELECT EXTRACT(EPOCH FROM (TO_TIMESTAMP('$datetime', 'DD.MM.YYYY HH24:MI:SS') - INTERVAL '1 hour'))::INTEGER;" | xargs)
    
    if [ "$mode_name" = "before" ]; then
        echo -e "${YELLOW}mode: adding points BEFORE $datetime (going backwards in time)${NC}"
    else
        echo -e "${YELLOW}mode: adding points AFTER $datetime (going forwards in time)${NC}"
    fi
    
    current_timestamp=$base_timestamp
    point_count=0
    
    echo -e "\n${GREEN}enter coordinates for each point (or type 'quit' to finish):${NC}\n"
    
    while true; do
        read -p "point $((point_count + 1)) - coordinates or 'quit': " input
        
        if [ "$input" = "quit" ]; then
            echo -e "\n${BLUE}finished! added $point_count points.${NC}"
            break
        fi
        
        latitude=$(echo "$input" | cut -d',' -f1 | xargs)
        longitude=$(echo "$input" | cut -d',' -f2 | xargs)
        
        if [ -z "$latitude" ] || [ -z "$longitude" ]; then
            echo -e "${RED}invalid format! try again.${NC}"
            continue
        fi
        
        if insert_point "$latitude" "$longitude" "$current_timestamp"; then
            display_time=$(date -d "@$current_timestamp" "+%d.%m.%Y %H:%M:%S")
            echo -e "${GREEN}✓ point $((point_count + 1)) added${NC} - lat: $latitude, lon: $longitude, time: $display_time"
            point_count=$((point_count + 1))
            current_timestamp=$((current_timestamp + interval))
        else
            echo -e "${RED}✗ error adding point${NC}"
        fi
    done
fi

echo -e "\n${GREEN}done!${NC}"
