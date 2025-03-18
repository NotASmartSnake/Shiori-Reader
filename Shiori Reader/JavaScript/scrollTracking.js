//
//  scrollTracking.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

// Calculate total character count once when page loads
let totalChars = document.getElementById('content').textContent.length;

// Use requestAnimationFrame for smooth performance
let ticking = false;
document.addEventListener('scroll', function() {
    if (!ticking) {
        window.requestAnimationFrame(function() {
            // Calculate progress based on scroll position
            const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
            const progress = window.scrollY / scrollHeight;
            
            // Only send a message when actually scrolling (avoid excess calculations)
            window.webkit.messageHandlers.scrollTrackingHandler.postMessage({
                action: "userScrolled",
                progress: progress,
                exploredChars: Math.round(totalChars * progress),
                totalChars: totalChars,
                currentPage: Math.ceil(progress * 100),
                scrollY: window.scrollY
            });
            
            ticking = false;
        });
        ticking = true;
    }
}, { passive: true });
