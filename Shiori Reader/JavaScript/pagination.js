//
//  pagination.js
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//

let paginationEnabled = false;
let currentPage = 0;
let totalPages = 0;
let pageWidth = 0;
let pageHeight = 0;

// Initialize pagination
function initPagination(enabled) {
    paginationEnabled = enabled;
    
    if (paginationEnabled) {
        setupPagination();
    } else {
        disablePagination();
    }
}

// Set up pagination
function setupPagination() {
    const content = document.getElementById('content');
    const isVerticalMode = document.body.classList.contains('vertical-text');
    
    // Update document styles for pagination
    document.body.classList.add('paginated');
    
    // Configure based on reading direction
    if (isVerticalMode) {
        // Vertical reading (right-to-left)
        setupVerticalPagination();
    } else {
        // Horizontal reading (left-to-right)
        setupHorizontalPagination();
    }
    
    // Calculate total pages
    calculatePages();
    
    // Position at current page
    goToPage(currentPage);
    
    // Report initial page information
    reportPageInfo();
}

function setupHorizontalPagination() {
    document.body.style.overflowX = 'hidden';
    document.body.style.overflowY = 'hidden';
    
    // Get dimensions for pagination
    pageWidth = window.innerWidth;
    pageHeight = window.innerHeight;
    
    // Add paged media CSS
    const pageStyle = document.createElement('style');
    pageStyle.id = 'paginationStyle';
    pageStyle.textContent = `
        body.paginated {
            column-width: ${pageWidth}px;
            column-gap: 40px;
            column-fill: auto;
            height: ${pageHeight}px;
            overflow: hidden !important;
            margin: 0;
            padding: 30px;
            box-sizing: border-box;
        }
        
        .page-controls {
            position: fixed;
            bottom: 20px;
            left: 0;
            right: 0;
            display: flex;
            justify-content: center;
            gap: 20px;
            z-index: 1000;
            pointer-events: none;
        }
        
        .page-controls button {
            pointer-events: auto;
        }
    `;
    document.head.appendChild(pageStyle);
    
    // Add touch and swipe handling
    addSwipeHandler();
}

function setupVerticalPagination() {
    document.body.style.overflowX = 'hidden';
    document.body.style.overflowY = 'hidden';
    
    // Get dimensions for pagination
    pageWidth = window.innerWidth;
    pageHeight = window.innerHeight;
    
    // Add paged media CSS for vertical text
    const pageStyle = document.createElement('style');
    pageStyle.id = 'paginationStyle';
    pageStyle.textContent = `
        body.paginated.vertical-text {
            writing-mode: vertical-rl;
            text-orientation: upright;
            column-width: ${pageHeight}px;
            column-gap: 40px;
            column-fill: auto;
            width: ${pageWidth}px;
            height: ${pageHeight}px;
            overflow: hidden !important;
            margin: 0;
            padding: 30px;
            box-sizing: border-box;
        }
        
        .page-controls {
            position: fixed;
            bottom: 20px;
            left: 0;
            right: 0;
            display: flex;
            justify-content: center;
            gap: 20px;
            z-index: 1000;
            pointer-events: none;
        }
        
        .page-controls button {
            pointer-events: auto;
        }
    `;
    document.head.appendChild(pageStyle);
    
    // For vertical text, we need special handling for RTL pagination
    document.body.style.direction = 'rtl';
    document.documentElement.style.direction = 'rtl';
    
    // Add touch and swipe handling
    addSwipeHandler();
    
    // Override some of the pagination functions for vertical text
    if (document.body.classList.contains('vertical-text')) {
        // Override nextPage function for RTL
        window.paginationAPI.nextPage = function() {
            // In RTL, next means moving left (decreasing page number)
            if (currentPage > 0) {
                goToPage(currentPage - 1);
            }
        };
        
        // Override previousPage function for RTL
        window.paginationAPI.previousPage = function() {
            // In RTL, previous means moving right (increasing page number)
            if (currentPage < totalPages - 1) {
                goToPage(currentPage + 1);
            }
        };
    }
}

function disablePagination() {
    // Remove pagination classes and styles
    document.body.classList.remove('paginated');
    const paginationStyle = document.getElementById('paginationStyle');
    if (paginationStyle) {
        paginationStyle.remove();
    }
    
    // Remove controls
    const controls = document.querySelector('.page-controls');
    if (controls) {
        controls.remove();
    }
    
    // Restore original overflow settings
    const isVerticalMode = document.body.classList.contains('vertical-text');
    if (isVerticalMode) {
        document.body.style.overflowX = 'auto';
        document.body.style.overflowY = 'hidden';
    } else {
        document.body.style.overflowX = 'hidden';
        document.body.style.overflowY = 'auto';
    }
    
    // Inform Swift about pagination mode change
    window.webkit.messageHandlers.paginationHandler.postMessage({
        action: "paginationDisabled"
    });
}

function calculatePages() {
    const content = document.getElementById('content');
    const isVerticalMode = document.body.classList.contains('vertical-text');
    
    if (isVerticalMode) {
        // For vertical text, columns go right-to-left
        totalPages = Math.ceil(content.scrollWidth / pageWidth);
    } else {
        // For horizontal text, calculate based on scroll width
        totalPages = Math.ceil(content.scrollWidth / pageWidth);
    }
    
    updatePageIndicator();
    
    // Report to Swift
    reportPageInfo();
}

function goToPage(pageNum) {
    if (pageNum < 0) pageNum = 0;
    if (pageNum >= totalPages) pageNum = totalPages - 1;
    
    currentPage = pageNum;
    
    const isVerticalMode = document.body.classList.contains('vertical-text');
    const offset = pageNum * pageWidth;
    
    if (isVerticalMode) {
        // For vertical text, scroll horizontally (RTL)
        window.scrollTo(offset, 0);
    } else {
        // For horizontal text, scroll horizontally (LTR)
        window.scrollTo(offset, 0);
    }
    
    updatePageIndicator();
    reportPageInfo();
}

function nextPage() {
    if (currentPage < totalPages - 1) {
        goToPage(currentPage + 1);
    }
}

function previousPage() {
    if (currentPage > 0) {
        goToPage(currentPage - 1);
    }
}

function updatePageIndicator() {
    const indicator = document.getElementById('page-indicator');
    if (indicator) {
        indicator.textContent = `Page ${currentPage + 1} of ${totalPages}`;
    }
}

function reportPageInfo() {
    // Send current page information to Swift
    window.webkit.messageHandlers.paginationHandler.postMessage({
        action: "pageChanged",
        currentPage: currentPage + 1,
        totalPages: totalPages,
        progress: totalPages > 0 ? (currentPage + 1) / totalPages : 0
    });
}

function addSwipeHandler() {
    let startX = 0;
    let startY = 0;
    
    document.addEventListener('touchstart', function(e) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
    }, { passive: true });
    
    document.addEventListener('touchend', function(e) {
        if (!paginationEnabled) return;
        
        const endX = e.changedTouches[0].clientX;
        const endY = e.changedTouches[0].clientY;
        const diffX = endX - startX;
        const diffY = endY - startY;
        
        // Detect horizontal swipe (threshold of 50px)
        if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY)) {
            const isVerticalMode = document.body.classList.contains('vertical-text');
            
            if (isVerticalMode) {
                // For vertical text mode (RTL pagination)
                if (diffX < 0) {
                    previousPage(); // Swipe left in vertical mode = previous page
                } else {
                    nextPage(); // Swipe right in vertical mode = next page
                }
            } else {
                // For horizontal text mode (LTR pagination)
                if (diffX < 0) {
                    nextPage(); // Swipe left in horizontal mode = next page
                } else {
                    previousPage(); // Swipe right in horizontal mode = previous page
                }
            }
        }
    }, { passive: true });
}

// Utility function to navigate to a specific position
function jumpToPosition(position) {
    if (!paginationEnabled) return;
    
    // Convert position (0-1) to page number
    const targetPage = Math.floor(position * totalPages);
    goToPage(targetPage);
}

// Handle window resize to recalculate pagination
window.addEventListener('resize', function() {
    if (paginationEnabled) {
        // Briefly disable and re-enable pagination to recalculate
        const temp = currentPage;
        disablePagination();
        setTimeout(() => {
            initPagination(true);
            goToPage(temp);
        }, 200);
    }
});

// Export functions for use from Swift
window.paginationAPI = {
    enable: () => initPagination(true),
    disable: () => initPagination(false),
    nextPage: nextPage,
    previousPage: previousPage,
    goToPage: goToPage,
    jumpToPosition: jumpToPosition
};
