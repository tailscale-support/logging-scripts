# Logging Scripts
Storage for specific device log collection scripts for additiuonal information that the Tailscale Support time might need to help troublshoot an issue.

# Usage - Linux / macOS
1. **Download the Script:** Either clone the repo or copy the contents of the script to a local file.

2. **Make the Script Executable:** Navigate to the directory where the script is located and make it executable.
```
chmod +x signNodes.sh
```
3. **Run the Script:** Execute the script
```
./getDebug.sh
```

4. **Provide Support with the collected logs:** The script will output a file in the directory that the script was run from, which will include the hostname of the device and a datestamp from when it was created. Please provide this file back to the Tailscale Support team.
