# AutoCreateSwapFile

Creates SwapFile for linux based servers based on RAM and Storage Availabilty.

There is only a 2GB offset(make changes as you wish), ie if the server available storage is 10GB the script will try to take upto 8GB for swap, ofcourse that depends on the amount of RAM.

The swapfile size is somewhat based on this logic https://aws.amazon.com/premiumsupport/knowledge-center/ec2-memory-swap-file/.

Use at your own risk.

## Usage
1. Copy the file to your server
2. Make the file Executable
  ```
  sudo chmod +x createswapfile.sh
  ```
 3. Execute the script
 ```
 sudo ./createswapfile.sh
 ```
