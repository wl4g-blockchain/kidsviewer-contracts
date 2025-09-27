import { app, BrowserWindow, BrowserView, ipcMain, shell, session } from 'electron';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { electronApp, optimizer, is } from '@electron-toolkit/utils';
import * as fs from 'fs';

// ES module equivalent of __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let mainWindow: BrowserWindow | null = null;
let videoView: BrowserView | null = null;
// Keep track of child windows for parental control
let videoWindows: BrowserWindow[] = [];

// Find the actual path of the preload script
function findPreloadPath() {
    // Development environment path
    const devPath = join(__dirname, '../preload/index.js');
    // Production environment possible paths
    const prodPath1 = join(__dirname, 'preload/index.js');
    const prodPath2 = join(__dirname, 'preload.js');
    const prodPath3 = join(app.getAppPath(), 'dist-electron/preload/index.js');
    const prodPath4 = join(app.getAppPath(), 'dist-electron', 'preload.js');

    // Check which path exists
    const paths = [devPath, prodPath1, prodPath2, prodPath3, prodPath4];
    for (const path of paths) {
        if (fs.existsSync(path)) {
            console.log('Found preload script:', path);
            return path;
        }
    }

    // If not found, return default path and record warning
    console.warn('⚠️ Unable to find preload script, using default path');
    console.log('Current directory:', __dirname);
    console.log('Application path:', app.getAppPath());
    return devPath;
}

// Update BrowserWindow configuration to fix preload script path issue
function createWindow(): void {
    // Use absolute path to ensure preload script can be found correctly
    const preloadPath = findPreloadPath();
    console.log('Preload script path:', preloadPath);

    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        minWidth: 800,
        minHeight: 600,
        show: false,
        autoHideMenuBar: true,
        webPreferences: {
            preload: preloadPath,
            sandbox: false,
            webSecurity: false, // Allow loading external content
            nodeIntegration: false,
            contextIsolation: true,
            allowRunningInsecureContent: true,
        },
        titleBarStyle: 'hiddenInset',
        vibrancy: 'under-window',
        visualEffectState: 'active',
    });

    // Preload script check.
    mainWindow.webContents.on('did-finish-load', () => {
        console.info('>>> Main window loaded - checking preload status');
        mainWindow?.webContents.executeJavaScript(`
      console.info("Checking the Electron API:", {
        hasElectronAPI: !!window.electronAPI, 
        apiKeys: window.electronAPI ? Object.keys(window.electronAPI) : [],
        windowProps: Object.keys(window).filter(k => k.includes('electron'))
      });
    `);
    });
    if (is.dev) {
        mainWindow.webContents.openDevTools();
    }

    // Show window when ready
    mainWindow.on('ready-to-show', () => {
        mainWindow!.show();
    });

    // Load app
    if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
        mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL']);
    } else {
        mainWindow.loadFile(join(__dirname, '../dist/index.html'));
    }

    // In development mode, handle navigation to prevent file:/// errors
    if (is.dev) {
        mainWindow.webContents.on('will-navigate', (event, navigationUrl) => {
            // Only allow navigation to localhost URLs in dev mode
            if (!navigationUrl.includes('localhost:5173')) {
                event.preventDefault();
                console.log('Prevented navigation to:', navigationUrl);
            }
        });
    }

    // Open external links in default browser
    mainWindow.webContents.setWindowOpenHandler(details => {
        shell.openExternal(details.url);
        return { action: 'deny' };
    });

    // Handle window close
    mainWindow.on('closed', () => {
        mainWindow = null;
        if (videoView) {
            videoView.webContents.close();
            videoView = null;
        }

        // Close all child video windows
        videoWindows.forEach(window => {
            if (!window.isDestroyed()) {
                window.close();
            }
        });
        videoWindows = [];
    });

    // Test IPC handler - only register if not already registered
    if (!ipcMain.listenerCount('ping')) {
        ipcMain.handle('ping', () => console.log('pong'));
    }
}

// Create video BrowserView for embedded content - Enhanced for third-party video support
function createVideoView(url: string, bounds: { x: number; y: number; width: number; height: number }) {
    if (!mainWindow) return null;

    // Destroy existing view if any
    if (videoView) {
        mainWindow.removeBrowserView(videoView);
        videoView.webContents.close();
    }

    // Configure CSP bypassing for all sessions
    session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
        if (details.responseHeaders) {
            // Remove Content-Security-Policy related headers
            delete details.responseHeaders['content-security-policy'];
            delete details.responseHeaders['content-security-policy-report-only'];
            delete details.responseHeaders['x-content-security-policy'];
            delete details.responseHeaders['x-webkit-csp'];
        }
        callback({
            responseHeaders: {
                ...details.responseHeaders,
                'Access-Control-Allow-Origin': ['*'],
            },
        });
    });

    videoView = new BrowserView({
        webPreferences: {
            webSecurity: false, // Disable web security to bypass CSP
            nodeIntegration: false,
            contextIsolation: false, // Allow access to window object for video scripts
            sandbox: false, // Disable sandbox for better video compatibility
            allowRunningInsecureContent: true, // Allow HTTP content on HTTPS sites
            experimentalFeatures: true, // Enable experimental features for better video support
            // Additional options for video website compatibility
            backgroundThrottling: false, // Prevent throttling during video playback
            offscreen: false, // Ensure proper rendering
            additionalArguments: [
                '--disable-web-security',
                '--disable-features=VizDisplayCompositor',
                '--disable-site-isolation-trials',
                '--allow-running-insecure-content',
                '--disable-xss-auditor',
                '--disable-background-timer-throttling',
                '--disable-backgrounding-occluded-windows',
                '--disable-renderer-backgrounding',
            ],
        },
    });

    // Modify CSP headers for this view
    videoView.webContents.session.webRequest.onHeadersReceived({ urls: ['*://*/*'] }, (details, callback) => {
        if (details.responseHeaders) {
            // Remove all CSP headers
            delete details.responseHeaders['content-security-policy'];
            delete details.responseHeaders['content-security-policy-report-only'];
        }
        callback({
            responseHeaders: {
                ...details.responseHeaders,
                'Access-Control-Allow-Origin': ['*'],
            },
        });
    });

    mainWindow.addBrowserView(videoView);
    videoView.setBounds(bounds);
    videoView.setAutoResize({ width: true, height: true });

    // Set user agent to mimic a regular browser for better compatibility
    videoView.webContents.setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    );

    // Handle console messages for debugging
    videoView.webContents.on('console-message', (event, level, message, line, sourceId) => {
        console.log(`Video console [${level}]:`, message);
    });

    // Handle navigation events with more detailed error handling
    videoView.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
        console.error(`Failed to load ${validatedURL}: ${errorDescription} (${errorCode})`);
        mainWindow?.webContents.send('video-load-error', { url: validatedURL, error: errorDescription });
    });

    videoView.webContents.on('did-finish-load', () => {
        console.log('Video content loaded successfully');
        mainWindow?.webContents.send('video-load-success', { url });
    });

    // Handle certificate errors
    videoView.webContents.on('certificate-error', (event, url, error, certificate, callback) => {
        // Accept all certificates for testing purposes
        event.preventDefault();
        callback(true);
    });

    // Prevent new window creation but allow navigation
    videoView.webContents.setWindowOpenHandler(details => {
        console.log('Prevented new window creation:', details.url);
        return { action: 'deny' };
    });

    // Block bitbrowser protocol requests
    try {
        videoView.webContents.session.protocol.interceptStringProtocol('bitbrowser', (request, callback) => {
            console.log('🚫 BrowserView blocked bitbrowser protocol request:', request.url);
            callback('');
        });
        console.log('✅ BrowserView bitbrowser protocol interceptor registered');
    } catch (error) {
        console.error('❌ Failed to register BrowserView bitbrowser interceptor:', error);
    }

    // Load the video URL
    try {
        videoView.webContents.loadURL(url, {
            userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            httpReferrer: url,
        });
    } catch (error) {
        console.error('Error loading video URL:', error);
        mainWindow?.webContents.send('video-load-error', { url, error: error instanceof Error ? error.message : 'Unknown error' });
    }

    return videoView;
}

// Create a separate window for video with enhanced CSP bypassing
function createVideoWindow(url: string, title: string = 'Video Player'): BrowserWindow {
    // Configure CSP bypassing for the session
    const videoWindowSession = session.fromPartition('video-window-session');

    videoWindowSession.webRequest.onHeadersReceived((details, callback) => {
        if (details.responseHeaders) {
            // Remove Content-Security-Policy related headers
            delete details.responseHeaders['content-security-policy'];
            delete details.responseHeaders['content-security-policy-report-only'];
            delete details.responseHeaders['x-content-security-policy'];
            delete details.responseHeaders['x-webkit-csp'];
        }
        callback({
            responseHeaders: {
                ...details.responseHeaders,
                'Access-Control-Allow-Origin': ['*'],
            },
        });
    });

    const videoWindow = new BrowserWindow({
        width: 1000,
        height: 800,
        title: title,
        autoHideMenuBar: true,
        webPreferences: {
            webSecurity: false,
            nodeIntegration: false,
            contextIsolation: true,
            session: videoWindowSession,
            sandbox: false,
            allowRunningInsecureContent: true,
            experimentalFeatures: true,
            additionalArguments: [
                '--disable-web-security',
                '--disable-features=VizDisplayCompositor',
                '--disable-site-isolation-trials',
                '--allow-running-insecure-content',
                '--disable-xss-auditor',
            ],
        },
    });

    // Set user agent to mimic a regular browser
    videoWindow.webContents.setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    );

    try {
        videoWindow.loadURL(url);

        // Track this window for parental control
        videoWindows.push(videoWindow);

        // When window is closed, remove from tracking array
        videoWindow.on('closed', () => {
            const index = videoWindows.indexOf(videoWindow);
            if (index > -1) {
                videoWindows.splice(index, 1);
            }
        });

        return videoWindow;
    } catch (error) {
        console.error('Error loading video URL in window:', error);
        videoWindow.close();
        throw error;
    }
}

// Close all video windows - useful for parental control timeouts
function closeAllVideoWindows() {
    videoWindows.forEach(window => {
        if (!window.isDestroyed()) {
            window.close();
        }
    });
    videoWindows = [];
}

// App event handlers
app.whenReady().then(() => {
    electronApp.setAppUserModelId('com.kidsviewer.app');

    // Global configuration: disable CSP and other security policies to allow third-party content embedding
    session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
        if (details.responseHeaders) {
            // Remove all CSP related headers
            delete details.responseHeaders['content-security-policy'];
            delete details.responseHeaders['content-security-policy-report-only'];
            delete details.responseHeaders['x-content-security-policy'];
            delete details.responseHeaders['x-webkit-csp'];
        }
        callback({
            responseHeaders: {
                ...details.responseHeaders,
                'Access-Control-Allow-Origin': ['*'],
            },
        });
    });

    console.log('Electron app ready, configured global CSP bypass');

    // Development mode setup
    if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
        console.log('Running in development mode');
    }

    createWindow();

    app.on('activate', function () {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

// Handle external protocol requests to prevent system popups
app.on('open-url', (event, url) => {
    console.log('🚫 App intercepted external protocol request:', url);
    // event.preventDefault();
});

// IPC handlers for video functionality - only register if not already registered
if (!ipcMain.listenerCount('create-video-view')) {
    ipcMain.handle('create-video-view', async (_, { url, bounds }) => {
        try {
            const view = createVideoView(url, bounds);
            return { success: !!view };
        } catch (error) {
            console.error('Error creating video view:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

if (!ipcMain.listenerCount('destroy-video-view')) {
    ipcMain.handle('destroy-video-view', async () => {
        try {
            if (videoView && mainWindow) {
                mainWindow.removeBrowserView(videoView);
                videoView.webContents.close();
                videoView = null;
            }
            return { success: true };
        } catch (error) {
            console.error('Error destroying video view:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

if (!ipcMain.listenerCount('update-video-bounds')) {
    ipcMain.handle('update-video-bounds', async (_, bounds) => {
        try {
            if (videoView) {
                videoView.setBounds(bounds);
            }
            return { success: true };
        } catch (error) {
            console.error('Error updating video bounds:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

// Enhanced IPC handlers for app functionality
// Modify open-url handler, use the same method as the video window
if (!ipcMain.listenerCount('open-url')) {
    ipcMain.handle('open-url', async (_, url: string) => {
        try {
            console.log('Opening URL in window:', url);
            // 使用与视频窗口相同的配置和CSP处理，确保安全策略一致
            const window = createVideoWindow(url, 'Web Content');
            return { success: true, windowId: window.id };
        } catch (error) {
            console.error('Error opening URL in window:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

// New IPC handler for separate video window with parental control capability
if (!ipcMain.listenerCount('open-video-window')) {
    ipcMain.handle('open-video-window', async (_, { url, title }) => {
        try {
            const window = createVideoWindow(url, title);
            return {
                success: true,
                windowId: window.id,
            };
        } catch (error) {
            return {
                success: false,
                error: error instanceof Error ? error.message : 'Unknown error',
            };
        }
    });
}

// New IPC handler to close a specific video window
if (!ipcMain.listenerCount('close-video-window')) {
    ipcMain.handle('close-video-window', async (_, windowId) => {
        try {
            const window = BrowserWindow.fromId(windowId);
            if (window && !window.isDestroyed()) {
                window.close();
            }
            return { success: true };
        } catch (error) {
            return {
                success: false,
                error: error instanceof Error ? error.message : 'Unknown error',
            };
        }
    });
}

// New IPC handler to close all video windows (for parental control)
if (!ipcMain.listenerCount('close-all-video-windows')) {
    ipcMain.handle('close-all-video-windows', async () => {
        try {
            closeAllVideoWindows();
            return { success: true };
        } catch (error) {
            return {
                success: false,
                error: error instanceof Error ? error.message : 'Unknown error',
            };
        }
    });
}

if (!ipcMain.listenerCount('get-app-version')) {
    ipcMain.handle('get-app-version', () => {
        return app.getVersion();
    });
}

// New IPC handlers for hiding/showing video content during questions
if (!ipcMain.listenerCount('hide-video-view')) {
    ipcMain.handle('hide-video-view', async () => {
        try {
            if (videoView) {
                // Hide by setting bounds to 0x0 at position -1000,-1000
                videoView.setBounds({ x: -1000, y: -1000, width: 0, height: 0 });
            }
            return { success: true };
        } catch (error) {
            console.error('Error hiding video view:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

if (!ipcMain.listenerCount('show-video-view')) {
    ipcMain.handle('show-video-view', async () => {
        try {
            if (videoView && mainWindow) {
                // Restore to original bounds
                const rect = mainWindow.getBounds();
                videoView.setBounds({ x: 0, y: 0, width: rect.width, height: rect.height });
            }
            return { success: true };
        } catch (error) {
            console.error('Error showing video view:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

if (!ipcMain.listenerCount('minimize-video-window')) {
    ipcMain.handle('minimize-video-window', async (_, windowId) => {
        try {
            const window = BrowserWindow.fromId(windowId);
            if (window && !window.isDestroyed()) {
                window.minimize();
            }
            return { success: true };
        } catch (error) {
            console.error('Error minimizing video window:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}

if (!ipcMain.listenerCount('restore-video-window')) {
    ipcMain.handle('restore-video-window', async (_, windowId) => {
        try {
            const window = BrowserWindow.fromId(windowId);
            if (window && !window.isDestroyed()) {
                window.restore();
                window.focus();
            }
            return { success: true };
        } catch (error) {
            console.error('Error restoring video window:', error);
            return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
        }
    });
}
