import express, { NextFunction, Request, Response } from 'express';
import path from 'path';
import { pong } from './pong';
import { connectToWifi } from './wifi-connect';
import { scanWifiNetworks } from './wifi-scan';


////////////////////////////// Setup ///////////////////////////////////////////

const HOST_NAME = 'splines.portal';
const FRONTEND_FOLDER = path.join(__dirname, '../', 'public');

const app = express();

// Redirect every request to our application
// https://raspberrypi.stackexchange.com/a/100118
// [You need a self-signed certificate if you really want 
// an https connection. In my experience, this is just a pain to do
// and probably overkill for a project where you have your own WiFi network
// without Internet access anyway.]
app.use((req: Request, res: Response, next: NextFunction) => {
    if (req.hostname != HOST_NAME) {
        return res.redirect(`http://${HOST_NAME}`);
    }
    next();
});

// Parse JSON bodies (must be before routes that need it)
app.use(express.json());

// Call this AFTER app.use where we do the redirects
app.use(express.static(FRONTEND_FOLDER));


/////////////////////////////// Endpoints //////////////////////////////////////

// Serve frontend
app.get('/', (req, res, next) => {
    res.sendFile(path.join(FRONTEND_FOLDER, 'index.html'));
});

app.get('/api/ping', pong);

// WiFi network scan endpoint
app.get('/api/scan-wifi', async (req: Request, res: Response) => {
    try {
        const networks = await scanWifiNetworks();
        res.json({ networks, success: true });
    } catch (error: any) {
        console.error('Error scanning WiFi networks:', error);
        res.status(500).json({ 
            error: error.message || 'Failed to scan WiFi networks',
            networks: [],
            success: false 
        });
    }
});

// WiFi connection endpoint
app.post('/api/connect-wifi', async (req: Request, res: Response) => {
    try {
        const { ssid, password } = req.body;
        
        if (!ssid) {
            return res.status(400).json({ error: 'SSID is required' });
        }
        
        // Password is optional for open networks, but we'll pass empty string if not provided
        const wifiPassword = password || '';
        
        // Call the WiFi connection script
        const result = await connectToWifi(ssid, wifiPassword);
        
        if (result.success) {
            res.json({ 
                message: 'WiFi credentials received. The device is connecting to your network...',
                success: true 
            });
        } else {
            res.status(500).json({ 
                error: result.error || 'Failed to configure WiFi connection',
                success: false 
            });
        }
    } catch (error: any) {
        console.error('Error connecting to WiFi:', error);
        res.status(500).json({ 
            error: error.message || 'Internal server error',
            success: false 
        });
    }
});


///////////////////////////// Server listening /////////////////////////////////

// Listen for requests
// If you change the port here, you have to adjust the ip tables as well
// see file: access-point/setup-access-point.sh
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Node version: ${process.version}`);
    console.log(`⚡ Raspberry Pi Server listening on port ${PORT}`);
});
