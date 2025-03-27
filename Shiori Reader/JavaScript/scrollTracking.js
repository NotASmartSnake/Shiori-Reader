//
//  scrollTracking.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

// Calculate total character count once when page loads
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
                // For vertical text, we need to account for the extra padding
                const safeAreaTop = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--safe-area-top') || '50');
                const safeAreaBottom = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--safe-area-bottom') || '34');
                const extraTopPadding = 60; // Match the value from CSS
                
                // Total vertical insets to account for
                const totalVerticalInsets = safeAreaTop + safeAreaBottom + extraTopPadding + 32; // 32 for the base padding (16px × 2)
                
                // Get adjusted scroll width that doesn't include our padding
                const scrollWidth = document.documentElement.scrollWidth;
                const adjustedScrollWidth = scrollWidth - totalVerticalInsets;
                
                // Calculate progress based on adjusted values
                progress = window.scrollX / (adjustedScrollWidth > 0 ? adjustedScrollWidth : scrollWidth);

            } else {
                // For horizontal text, use vertical scrolling (your existing code)
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
