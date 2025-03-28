//
//  scrollLock.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/27/25.
//

document.addEventListener('DOMContentLoaded', function() {
    // Detect if we're in vertical mode
    const isVerticalMode = document.body.classList.contains('vertical-text');
    
    // Apply proper overflow settings
    if (isVerticalMode) {
        // Vertical text - horizontal scrolling only
        document.documentElement.style.overflowX = 'auto';
        document.documentElement.style.overflowY = 'hidden';
        document.body.style.overflowX = 'auto';
        document.body.style.overflowY = 'hidden';
        
        // Prevent vertical scrolling with touch events
        document.body.addEventListener('touchmove', function(e) {
            const touch = e.touches[0];
            const startY = touch.pageY;
            
            // Check if this is primarily vertical movement
            document.body.addEventListener('touchmove', function detectDirection(e) {
                const currentTouch = e.touches[0];
                const diffY = Math.abs(currentTouch.pageY - startY);
                const diffX = Math.abs(currentTouch.pageX - touch.pageX);
                
                // If movement is more vertical than horizontal, prevent it
                if (diffY > diffX) {
                    e.preventDefault();
                }
                
                // Remove this temporary listener
                document.body.removeEventListener('touchmove', detectDirection);
            }, { once: true });
        });
    } else {
        // Horizontal text - vertical scrolling only
        document.documentElement.style.overflowX = 'hidden';
        document.documentElement.style.overflowY = 'auto';
        document.body.style.overflowX = 'hidden';
        document.body.style.overflowY = 'auto';
        
        // Prevent horizontal scrolling with touch events
        document.body.addEventListener('touchmove', function(e) {
            const touch = e.touches[0];
            const startX = touch.pageX;
            
            // Check if this is primarily horizontal movement
            document.body.addEventListener('touchmove', function detectDirection(e) {
                const currentTouch = e.touches[0];
                const diffX = Math.abs(currentTouch.pageX - startX);
                const diffY = Math.abs(currentTouch.pageY - touch.pageY);
                
                // If movement is more horizontal than vertical, prevent it
                if (diffX > diffY) {
                    e.preventDefault();
                }
                
                // Remove this temporary listener
                document.body.removeEventListener('touchmove', detectDirection);
            }, { once: true });
        });
    }
});

// When reading direction changes, update overflow settings
function updateScrollLock(isVerticalMode) {
    if (isVerticalMode) {
        document.documentElement.style.overflowX = 'auto';
        document.documentElement.style.overflowY = 'hidden';
        document.body.style.overflowX = 'auto';
        document.body.style.overflowY = 'hidden';
    } else {
        document.documentElement.style.overflowX = 'hidden';
        document.documentElement.style.overflowY = 'auto';
        document.body.style.overflowX = 'hidden';
        document.body.style.overflowY = 'auto';
    }
}
