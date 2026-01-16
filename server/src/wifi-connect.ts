import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

interface WifiConnectResult {
    success: boolean;
    error?: string;
}

export async function connectToWifi(ssid: string, password: string): Promise<WifiConnectResult> {
    try {
        // Escape special characters in SSID and password for shell
        // Use single quotes and escape single quotes within
        const escapedSsid = ssid.replace(/'/g, "'\\''");
        const escapedPassword = password.replace(/'/g, "'\\''");
        
        // Execute the connection script (should be in /usr/local/bin after setup)
        const scriptPath = '/usr/local/bin/switch-to-wifi-client.sh';
        
        try {
            // Use single quotes to properly handle special characters
            const command = `sudo ${scriptPath} '${escapedSsid}' '${escapedPassword}'`;
            console.log('Executing WiFi connection command...');
            
            const { stdout, stderr } = await execAsync(command, {
                timeout: 60000, // 60 second timeout
            });
            
            console.log('WiFi connection script output:', stdout);
            if (stderr) {
                console.error('WiFi connection script stderr:', stderr);
            }
            
            return { success: true };
        } catch (error: any) {
            console.error('Error executing WiFi connection script:', error);
            const errorMessage = error.stderr || error.message || 'Failed to execute connection script';
            return { 
                success: false, 
                error: errorMessage
            };
        }
    } catch (error: any) {
        console.error('Error in connectToWifi:', error);
        return { 
            success: false, 
            error: error.message || 'Unknown error occurred' 
        };
    }
}
