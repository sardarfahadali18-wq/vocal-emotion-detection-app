# Setting Up Your Computer as a WiFi Hotspot for Voice Emotion App

Your Android phone is configured to connect to server at IP address `192.168.228.12:5000`, but this IP is not currently configured on your computer. Here's how to set it up:

## Option 1: Turn on Windows Mobile Hotspot

1. **Open Settings**:

   - Press `Win + I` to open Windows Settings
   - Or click the Start menu and select Settings

2. **Go to Network & Internet**:

   - Select "Network & Internet"
   - Click on "Mobile hotspot" in the left sidebar

3. **Set Up Mobile Hotspot**:

   - Toggle "Share my Internet connection with other devices" to ON
   - Set "Share my Internet connection from" to your active internet connection
   - Set "Share over" to "Wi-Fi"
   - Click on "Edit" to set your own network name and password if desired
   - Click "Save"

4. **Connect Your Phone to This Hotspot**:

   - On your Android phone, go to Wi-Fi settings
   - Connect to the hotspot you just created
   - The IP address of your computer should now be `192.168.137.1` (Windows default)

5. **Update Your Flutter App**:
   - Since the default hotspot IP is usually `192.168.137.1`, not `192.168.228.12`,
     you may need to update the server URL in your Flutter app to:
     `http://192.168.137.1:5000`

## Option 2: Change the Server URL in Your Flutter App

If you can't set up the computer with IP `192.168.228.12`, update your Flutter app instead:

1. **Find Your Computer's IP Address**:

   - Run `ipconfig` in Command Prompt or PowerShell
   - Look for your active connection (WiFi or Ethernet) and find the IPv4 Address

2. **Make Sure Both Devices are on the Same Network**:

   - Your computer and phone must be connected to the same WiFi network

3. **Update the Flutter App Settings**:
   - Open the app on your phone
   - Tap the Settings icon (gear)
   - Enter your computer's actual IP address (e.g., `http://192.168.56.1:5000`)
   - Save the settings

## Troubleshooting

If you still have connection issues:

1. **Check Windows Firewall**:

   - Make sure Windows Firewall allows Python and Flask to access the network
   - You might need to add an exception for port 5000

2. **Test Local Connection**:

   - On your computer, run: `python test_connection.py --url http://localhost:5000`
   - This tests if the server is running correctly

3. **Ensure Server is Visible on Network**:
   - Try accessing the server from another device on the same network
   - If it doesn't work, check router settings or try a different network

## For Advanced Users: Set a Static IP (192.168.228.12)

If you really need to use exactly `192.168.228.12`:

1. Open Network Connections (Win+R, type `ncpa.cpl`)
2. Right-click your active connection and select Properties
3. Select "Internet Protocol Version 4 (TCP/IPv4)" and click Properties
4. Select "Use the following IP address"
5. Enter:
   - IP address: 192.168.228.12
   - Subnet mask: 255.255.255.0
   - Default gateway: (your current gateway)
6. Click OK

Note: This might disrupt your existing network connection. Only do this if you know what you're doing.
