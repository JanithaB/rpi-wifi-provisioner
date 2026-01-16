// WiFi form handling
const wifiForm = document.getElementById('wifi-form');
const submitBtn = document.getElementById('submit-btn');
const messageDiv = document.getElementById('message');
const ssidSelect = document.getElementById('ssid');
const ssidManual = document.getElementById('ssid-manual');
const scanBtn = document.getElementById('scan-btn');
const networkInfo = document.getElementById('network-info');
const manualToggle = document.getElementById('manual-toggle');
let isManualMode = false;

function showMessage(text, type) {
    messageDiv.textContent = text;
    messageDiv.className = `message ${type}`;
    messageDiv.style.display = 'block';
}

function hideMessage() {
    messageDiv.style.display = 'none';
}

// Scan for WiFi networks
async function scanNetworks() {
    scanBtn.disabled = true;
    scanBtn.textContent = 'Scanning...';
    ssidSelect.innerHTML = '<option value="">Scanning...</option>';
    networkInfo.textContent = '';
    hideMessage();
    
    try {
        const response = await fetch('/api/scan-wifi');
        const data = await response.json();
        
        if (data.success && data.networks && data.networks.length > 0) {
            // Clear and populate dropdown
            ssidSelect.innerHTML = '<option value="">Select a network...</option>';
            
            data.networks.forEach(network => {
                const option = document.createElement('option');
                option.value = network.ssid;
                const signalBars = '█'.repeat(Math.floor(network.signal / 20));
                const signalText = network.signal > 0 ? ` (${signalBars} ${network.signal}%)` : '';
                option.textContent = `${network.ssid}${signalText} - ${network.encryption}`;
                option.dataset.encryption = network.encryption;
                option.dataset.signal = network.signal;
                ssidSelect.appendChild(option);
            });
            
            scanBtn.textContent = 'Scan for Networks';
            scanBtn.disabled = false;
        } else {
            ssidSelect.innerHTML = '<option value="">No networks found. Try scanning again.</option>';
            scanBtn.textContent = 'Scan for Networks';
            scanBtn.disabled = false;
            showMessage('No WiFi networks found. Make sure you are in range of WiFi networks.', 'info');
        }
    } catch (error) {
        console.error('Error scanning networks:', error);
        ssidSelect.innerHTML = '<option value="">Scan failed. Try again or enter manually.</option>';
        scanBtn.textContent = 'Scan for Networks';
        scanBtn.disabled = false;
        showMessage('Failed to scan for networks. You can enter the network name manually.', 'error');
    }
}

// Handle network selection
ssidSelect.addEventListener('change', (e) => {
    const selectedOption = e.target.options[e.target.selectedIndex];
    if (selectedOption && selectedOption.dataset.encryption) {
        const encryption = selectedOption.dataset.encryption;
        const signal = selectedOption.dataset.signal;
        if (encryption === 'Open') {
            networkInfo.textContent = 'This network is open (no password required).';
            document.getElementById('password').required = false;
        } else {
            networkInfo.textContent = `This network requires a password (${encryption}).`;
            document.getElementById('password').required = true;
        }
    } else {
        networkInfo.textContent = '';
    }
});

// Toggle manual entry
manualToggle.addEventListener('click', (e) => {
    e.preventDefault();
    isManualMode = !isManualMode;
    
    if (isManualMode) {
        ssidSelect.style.display = 'none';
        scanBtn.style.display = 'none';
        ssidManual.style.display = 'block';
        ssidManual.required = true;
        ssidSelect.required = false;
        manualToggle.textContent = 'Select from scanned networks';
        networkInfo.textContent = '';
    } else {
        ssidSelect.style.display = 'block';
        scanBtn.style.display = 'inline-block';
        ssidManual.style.display = 'none';
        ssidManual.required = false;
        ssidSelect.required = true;
        manualToggle.textContent = 'Enter network name manually';
    }
});

// Scan button click
scanBtn.addEventListener('click', scanNetworks);

// Auto-scan on page load
scanNetworks();

wifiForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // Get SSID from either dropdown or manual input
    const ssid = isManualMode 
        ? ssidManual.value.trim() 
        : ssidSelect.value.trim();
    const password = document.getElementById('password').value;
    
    // Check if password is required (not for open networks)
    const selectedOption = ssidSelect.options[ssidSelect.selectedIndex];
    const isOpenNetwork = selectedOption && selectedOption.dataset.encryption === 'Open';
    
    if (!ssid) {
        showMessage('Please select or enter a WiFi network name', 'error');
        return;
    }
    
    if (!isOpenNetwork && !password) {
        showMessage('Please enter the WiFi password', 'error');
        return;
    }
    
    submitBtn.disabled = true;
    submitBtn.textContent = 'Connecting...';
    hideMessage();
    
    try {
        const response = await fetch('/api/connect-wifi', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ ssid, password }),
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showMessage(data.message || 'WiFi credentials received. The device is now connecting to your network. This may take a minute...', 'success');
            submitBtn.textContent = 'Connected';
        } else {
            showMessage(data.error || 'Failed to connect to WiFi. Please try again.', 'error');
            submitBtn.disabled = false;
            submitBtn.textContent = 'Connect to WiFi';
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('Network error. Please check your connection and try again.', 'error');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Connect to WiFi';
    }
});
