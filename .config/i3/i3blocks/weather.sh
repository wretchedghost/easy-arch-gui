#!/bin/bash
# Copyright (C) 2016 Ning Sun <sunng@about.me>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

CITY=$BLOCK_INSTANCE
APPID="09c94be38f4d69d4e535f3baf9d8c367"

OUTPUT=$(http get http://api.openweathermap.org/data/2.5/weather\?APPID\=${APPID}\&q\=${CITY}\&units\=imperial)

#echo $APPID
#echo $OUTPUT

TEMP=$(echo $OUTPUT | jq -r ".main.temp")
WEATHER=$(echo $OUTPUT | jq -r ".weather[0].main")
case $WEATHER in
    "Clear"*)
        WEATHER=
        ;;
    "Rain"*)
        WEATHER=
        ;;
    "Snow"*)
        WEATHER=
        ;;
    "Thunderstorm"*)
        WEATHER=
        ;;
esac

echo "$WEATHER $TEMP°F"
echo "$TEMP°F"
