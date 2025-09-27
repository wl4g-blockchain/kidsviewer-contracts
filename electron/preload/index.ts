import { contextBridge, ipcRenderer } from 'electron';

console.info('Loading preload script [' + new Date().toISOString() + ']');

// Ensure the script is executed before the DOM is ready
const exposeAPI = () => {
  try {
    console.info('Attempting to expose API to renderer process...');

    const api = {
      ping: () => ipcRenderer.invoke('ping'),
      openUrl: (url: string) => ipcRenderer.invoke('open-url', url),
      getAppVersion: () => ipcRenderer.invoke('get-app-version'),

      // Video BrowserView APIs
      createVideoView: (params: { url: string; bounds: { x: number; y: number; width: number; height: number } }) =>
        ipcRenderer.invoke('create-video-view', params),
      destroyVideoView: () => ipcRenderer.invoke('destroy-video-view'),
      updateVideoBounds: (bounds: { x: number; y: number; width: number; height: number }) =>
        ipcRenderer.invoke('update-video-bounds', bounds),

      // Video event listeners
      onVideoLoadError: (callback: (data: { url: string; error: string }) => void) => {
        ipcRenderer.on('video-load-error', (_, data) => callback(data));
      },
      onVideoLoadSuccess: (callback: (data: { url: string }) => void) => {
        ipcRenderer.on('video-load-success', (_, data) => callback(data));
      },

      // Remove listeners
      removeVideoListeners: () => {
        ipcRenderer.removeAllListeners('video-load-error');
        ipcRenderer.removeAllListeners('video-load-success');
      },

      // Enhanced video window management - for separate window approach
      openVideoWindow: (params: { url: string; title?: string }) => ipcRenderer.invoke('open-video-window', params),
      closeVideoWindow: (windowId: number) => ipcRenderer.invoke('close-video-window', windowId),
      closeAllVideoWindows: () => ipcRenderer.invoke('close-all-video-windows'),

      // Video visibility control for questions
      hideVideoView: () => ipcRenderer.invoke('hide-video-view'),
      showVideoView: () => ipcRenderer.invoke('show-video-view'),
      minimizeVideoWindow: (windowId: number) => ipcRenderer.invoke('minimize-video-window', windowId),
      restoreVideoWindow: (windowId: number) => ipcRenderer.invoke('restore-video-window', windowId),
    };

    // Test if IPC channel is working
    ipcRenderer.invoke('ping').catch(err => {
      console.error('IPC test failed:', err);
    });

    // 暴露API到window对象
    contextBridge.exposeInMainWorld('electronAPI', api);

    console.info('API successfully exposed to renderer process:', Object.keys(api));

    // 添加一个标记，以便在渲染进程中检查preload是否正确执行
    contextBridge.exposeInMainWorld('__ELECTRON_PRELOAD_EXECUTED__', true);
  } catch (error) {
    console.error('Expose API failed:', error);
  }
};

// Immediately execute once
exposeAPI();

// Ensure the API is ready after the DOM is loaded
const waitForDOM = () => {
  try {
    if (typeof document !== 'undefined') {
      document.addEventListener('DOMContentLoaded', () => {
        // Checking APIs exposed in the window object
        const win = window as any;
        if (!win.electronAPI) {
          console.warn('DOMContentLoadedEvent: but electronAPI is not exist, trying to expose again');
          exposeAPI();
        } else {
          console.info('DOMContentLoadedEvent: electronAPI is exist');
        }
      });
    }
  } catch (e) {
    console.error('Waiting DOM event error:', e);
  }
};

// 尝试等待DOM事件
setTimeout(waitForDOM, 0);

// Type definitions for the exposed API
declare global {
  interface Window {
    __ELECTRON_PRELOAD_EXECUTED__: boolean;
    electronAPI: {
      ping: () => Promise<void>;
      openUrl: (url: string) => Promise<{ success: boolean; error?: string }>;
      getAppVersion: () => Promise<string>;

      // Video BrowserView APIs
      createVideoView: (params: {
        url: string;
        bounds: { x: number; y: number; width: number; height: number };
      }) => Promise<{ success: boolean; error?: string }>;
      destroyVideoView: () => Promise<{ success: boolean; error?: string }>;
      updateVideoBounds: (bounds: { x: number; y: number; width: number; height: number }) => Promise<{ success: boolean; error?: string }>;

      // Video event listeners
      onVideoLoadError: (callback: (data: { url: string; error: string }) => void) => void;
      onVideoLoadSuccess: (callback: (data: { url: string }) => void) => void;
      removeVideoListeners: () => void;

      // Enhanced video window management - for separate window approach
      openVideoWindow: (params: { url: string; title?: string }) => Promise<{ success: boolean; windowId?: number; error?: string }>;
      closeVideoWindow: (windowId: number) => Promise<{ success: boolean; error?: string }>;
      closeAllVideoWindows: () => Promise<{ success: boolean; error?: string }>;
    };
  }
}
