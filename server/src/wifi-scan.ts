import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface WifiNetwork {
    ssid: string;
    encryption: string;
    signal: number;
}

export async function scanWifiNetworks(): Promise<WifiNetwork[]> {
    try {
        const scriptPath = '/usr/local/bin/scan-wifi-networks.sh';
        
        try {
            const { stdout, stderr } = await execAsync(`sudo ${scriptPath}`, {
                timeout: 30000, // 30 second timeout
            });
            
            if (stderr && !stdout) {
                console.error('WiFi scan stderr:', stderr);
                return [];
            }
            
            // Parse the output - format: SSID|Encryption|Signal
            const networks: WifiNetwork[] = [];
            const lines = stdout.trim().split('\n').filter(line => line.trim());
            
            for (const line of lines) {
                const parts = line.split('|');
                if (parts.length >= 2) {
                    const ssid = parts[0].trim();
                    const encryption = parts[1].trim() || 'Unknown';
                    const signal = parts.length >= 3 ? parseInt(parts[2].trim(), 10) || 0 : 0;
                    
                    // Only add non-empty SSIDs
                    if (ssid) {
                        networks.push({
                            ssid,
                            encryption,
                            signal: isNaN(signal) ? 0 : signal,
                        });
                    }
                }
            }
            
            // Remove duplicates (keep the one with highest signal)
            const uniqueNetworks = new Map<string, WifiNetwork>();
            for (const network of networks) {
                const existing = uniqueNetworks.get(network.ssid);
                if (!existing || network.signal > existing.signal) {
                    uniqueNetworks.set(network.ssid, network);
                }
            }
            
            // Sort by signal strength (descending)
            return Array.from(uniqueNetworks.values()).sort((a, b) => b.signal - a.signal);
        } catch (error: any) {
            console.error('Error executing WiFi scan script:', error);
            // Return empty array on error rather than throwing
            return [];
        }
    } catch (error: any) {
        console.error('Error in scanWifiNetworks:', error);
        return [];
    }
}
