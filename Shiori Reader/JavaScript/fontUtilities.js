//
//  fontUtilities.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

function updateFontSize(size) {
    document.documentElement.style.setProperty('--shiori-font-size', size + 'px');
    console.log('Font size updated to: ' + size + 'px');
    return true;
}

function enforceRubyTextSize(baseFontSize) {
    // If baseFontSize is not a number, try to get the computed value
    if (typeof baseFontSize !== 'number') {
        // Get the computed value of --shiori-font-size
        const computedStyle = getComputedStyle(document.documentElement);
        const fontSizeValue = computedStyle.getPropertyValue('--shiori-font-size').trim();
        
        // Extract the numeric value (removing 'px')
        baseFontSize = parseInt(fontSizeValue) || 18;
        console.log('Computed base font size:', baseFontSize);
    }
    
    // Get all rt elements
    const rtElements = document.querySelectorAll('rt');
    
    // Set a proper size, only if it's not already set by CSS
    for (const rt of rtElements) {
        // Calculate the proper size (half of base font size)
        const rubyFontSize = Math.round(baseFontSize * 0.5);
        
        // Apply the size only if it's different from what CSS would set
        const currentSize = parseInt(getComputedStyle(rt).fontSize);
        
        // Only apply if the current size is significantly different
        // This prevents double-application
        if (Math.abs(currentSize - rubyFontSize) > 2) {
            rt.style.cssText = 'font-size: ' + rubyFontSize + 'px !important';
            console.log('Applied ruby text size:', rubyFontSize + 'px', 'Previous size was:', currentSize + 'px');
        }
    }
    
    return rtElements.length;
}

// Self-executing initialization
(function() {
    // Wait for the document to be fully loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeFonts);
    } else {
        // Document already loaded
        initializeFonts();
    }
    
    function initializeFonts() {
        console.log('fontUtilities.js: Initializing font utilities');
        
        // Get the computed value instead of trying to read the style property directly
        const computedStyle = getComputedStyle(document.documentElement);
        const fontSizeValue = computedStyle.getPropertyValue('--shiori-font-size').trim();
        const baseFontSize = parseInt(fontSizeValue) || 18;
        
        console.log('Initial font size from CSS:', fontSizeValue);
        
        // Apply ruby sizing
        const rubyCount = enforceRubyTextSize(baseFontSize);
        console.log('Applied sizing to', rubyCount, 'ruby text elements');
        
        // For late-loaded content, check again after a delay
        // But only do it once to avoid double-application
        setTimeout(function() {
            const newRubyCount = enforceRubyTextSize(baseFontSize);
            console.log('Late check: Found', newRubyCount, 'ruby text elements');
        }, 1000);
    }
})();
