// consoleLogger.js

(function() {
    // Store original functions FIRST
    const originalLog = console.log;
    const originalWarn = console.warn;
    const originalError = console.error;

    // Define a safe sending function
    function sendLogToSwift(level, message) {
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[`console${level}`]) {
                window.webkit.messageHandlers[`console${level}`].postMessage(message);
            }
        } catch(e) {
            // Don't use console here to avoid recursion
            // Just silently fail
        }
    }

    // Override console.log
    console.log = function() {
        // Convert all arguments to a single string
        const message = Array.from(arguments).map(arg => {
            if (typeof arg === 'object') {
                try { return JSON.stringify(arg); }
                catch(e) { return String(arg); }
            }
            return String(arg);
        }).join(' ');
        
        // Send to Swift
        sendLogToSwift('Log', message);
        
        // Call original function
        originalLog.apply(console, arguments);
    };

    // Override console.warn
    console.warn = function() {
        // Convert all arguments to a single string
        const message = Array.from(arguments).map(arg => {
            if (typeof arg === 'object') {
                try { return JSON.stringify(arg); }
                catch(e) { return String(arg); }
            }
            return String(arg);
        }).join(' ');
        
        // Send to Swift
        sendLogToSwift('Warn', message);
        
        // Call original function
        originalWarn.apply(console, arguments);
    };

    // Override console.error
    console.error = function() {
        // Convert all arguments to a single string
        const message = Array.from(arguments).map(arg => {
            if (typeof arg === 'object') {
                try { return JSON.stringify(arg); }
                catch(e) { return String(arg); }
            }
            return String(arg);
        }).join(' ');
        
        // Send to Swift
        sendLogToSwift('Error', message);
        
        // Call original function
        originalError.apply(console, arguments);
    };

    // Log that installation was successful
    originalLog("Console logger installed successfully");
})();
