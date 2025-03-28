//
//  safeArea.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/26/25.
//

document.addEventListener('DOMContentLoaded', function() {
    // Handle vertical mode specifically
    if (document.body.classList.contains('vertical-text')) {
        // Set large fixed padding to avoid dynamic island
        document.body.style.paddingTop = '70px';
        document.body.style.paddingLeft = '16px';
        document.body.style.paddingRight = '16px';
    }
    
    // For both modes, make sure content is visible
    const content = document.getElementById('content');
    if (content) {
        // Add a small delay to ensure the DOM is fully rendered
        setTimeout(function() {
            console.log('Applying safety margins to content');
            
            // Apply additional margin for text safety
            if (document.body.classList.contains('vertical-text')) {
                // Ensure no text is under the dynamic island in vertical mode
                const firstChild = content.firstElementChild;
                if (firstChild) {
                    firstChild.style.marginTop = '50px';
                }
            }
        }, 300);
    }
});
