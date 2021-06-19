#!/bin/bash

# Get Current Swap Space
CURRENTSWAP=$( cat /proc/meminfo | grep SwapTotal | awk '{print $2}' )

# If Swap already present, Exit
if [ $CURRENTSWAP -gt 0 ]
then
    echo "Got swap $CURRENTSWAP"
    exit 1
fi

# Get Total Free Space
TOTALFREE=$( df --output=avail / | tail -1 )
echo "Total Free Space : $TOTALFREE"

# Allocate approx 2GB as Storage for APP and Logs
APPSTORAGE=2000000
MINSWAP=32000

# Total Usable Storage for SWAP
TOTALUSABLE=$(($TOTALFREE-$APPSTORAGE))
echo "Total Usable Space : $TOTALUSABLE"

#Exit if total usable space is less than 32MB
if [ $TOTALUSABLE -lt 32000 ]
then
    echo "Not Enough Space"
    exit 1
fi

# Get System Total Memory
TOTALMEM=$( free -t | tail -1 | awk '{print $2}' )
echo "Total System Memory : $TOTALMEM"

# Inititalize & calculate SwapPartition Size
SWAPSPACE=0
if [ $TOTALMEM -gt 32000000 ]
then
    SWAPSPACE=$TOTALMEM
else
    if [ $TOTALMEM -gt 2000000 ]
    then
    	SWAPSPACE=$(( 4000000 + $TOTALMEM - 2000000 ))
    else
    	SWAPSPACE=$(( 2 * $TOTALMEM ))
    fi
fi

# ALWAYS have a min of 32MB SWAP 
# Just a Gaurd Condition, not realistic in the current scenario
if [ $SWAPSPACE -lt $MINSWAP ]
then
    SWAPSPACE=$MINSWAP
fi

# Dont Exceed Available Storage Space
SWAPSPACE=$(( $TOTALUSABLE > $SWAPSPACE ? $SWAPSPACE : $TOTALUSABLE ))

echo "Swap Space Selected : $SWAPSPACE"

# Calculate BlockSize
FREEMEM=$( free | grep Mem | awk '{print $4}' )

if [ $FREEMEM -lt 8000 ]
then
    echo "Not Enough Memory to create SWAP"
    exit 1
fi

if [ $FREEMEM -gt 256000 ]
then
   BLOCKSIZE=128
else
   BLOCKSIZE=8
fi

echo "Block Size : $BLOCKSIZE"

# Find BlockCounts
BCOUNT=$(( $SWAPSPACE / ($BLOCKSIZE * 1000) ))
echo "Block Count : $BCOUNT"


####### Actual Creation of Swap File ########
SWAPFILE=/swapfile

# Create Swap File
dd if=/dev/zero of=$SWAPFILE bs="$BLOCKSIZE""M" count=$BCOUNT

# Update Permission for Swap File
chmod 600 $SWAPFILE

# Setup Linux Swap Area
mkswap $SWAPFILE

# Enable swap
swapon $SWAPFILE

# Enable swap to persist between reboots
echo "$SWAPFILE swap swap defaults 0 0" >> /etc/fstab

# Exit
exit 0
