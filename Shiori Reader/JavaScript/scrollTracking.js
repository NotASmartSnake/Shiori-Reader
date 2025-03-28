//
//  scrollTracking.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

let totalChars = document.getElementById('content').textContent.length;
let ticking = false;

document.addEventListener('scroll', function() {
    // Detect if we're in vertical mode
    const isVerticalMode = document.body.classList.contains('vertical-text');
    
    if (!ticking) {
        window.requestAnimationFrame(function() {
            // For vertical mode, calculate progress differently
            let progress, scrollHeight;
            
            if (isVerticalMode) {
                // For vertical text (RTL), we need the total scrollable width
                const scrollWidth = document.documentElement.scrollWidth;
                const viewportWidth = window.innerWidth;
                const maxScrollX = scrollWidth - viewportWidth;
                
                // Calculate progress based on negative scrollX values
                // As we scroll left, scrollX becomes more negative
                progress = maxScrollX > 0 ? Math.abs(window.scrollX) / maxScrollX : 0;
                
                // Check if the scroll position is actually being maintained
                console.log("Tracking: scrollX = " + window.scrollX + " of maxScrollX = " + maxScrollX);
            } else {
                // For horizontal text, use vertical scrolling (original code)
                scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                progress = window.scrollY / scrollHeight;
            }
            
            // Send progress to Swift
            window.webkit.messageHandlers.scrollTrackingHandler.postMessage({
                action: "userScrolled",
                progress: progress,
                exploredChars: Math.round(totalChars * progress),
                totalChars: totalChars,
                currentPage: Math.ceil(progress * 100),
                scrollX: window.scrollX,
                scrollY: window.scrollY,
                isVerticalMode: isVerticalMode
            });
            
            ticking = false;
        });
        ticking = true;
    }
}, { passive: true });

// Debug function to check scroll dimensions
function debugScrollDimensions() {
    const isVerticalMode = document.body.classList.contains('vertical-text');
    console.log("DEBUG: Reading direction: " + (isVerticalMode ? "vertical" : "horizontal"));
    console.log("DEBUG: document.documentElement.scrollWidth: " + document.documentElement.scrollWidth);
    console.log("DEBUG: document.documentElement.clientWidth: " + document.documentElement.clientWidth);
    console.log("DEBUG: document.documentElement.scrollHeight: " + document.documentElement.scrollHeight);
    console.log("DEBUG: document.documentElement.clientHeight: " + document.documentElement.clientHeight);
    console.log("DEBUG: window.innerWidth: " + window.innerWidth);
    console.log("DEBUG: window.innerHeight: " + window.innerHeight);
    
    const content = document.getElementById('content');
    if (content) {
        console.log("DEBUG: content.scrollWidth: " + content.scrollWidth);
        console.log("DEBUG: content.offsetWidth: " + content.offsetWidth);
        console.log("DEBUG: content.getBoundingClientRect().width: " + content.getBoundingClientRect().width);
    }
}

// Call this function when the page loads
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(debugScrollDimensions, 500);
});
