//
//  positionManagement.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

// Store more detailed position information
let lastKnownPosition = {
    percentage: 0,
    pixelOffset: 0,
    elementId: null,
    elementOffset: 0
};

// Enhance the tracking function to store more context
function trackPosition() {
    const content = document.getElementById('content');
    if (!content) return;
    
    const maxScroll = content.scrollHeight - window.innerHeight;
    const currentScroll = window.scrollY;
    
    // Save detailed position info
    lastKnownPosition.percentage = maxScroll > 0 ? currentScroll / maxScroll : 0;
    lastKnownPosition.pixelOffset = currentScroll;
    
    // Try to identify a nearby element as a landmark
    const elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, div.chapter');
    let closestElement = null;
    let closestDistance = Number.MAX_VALUE;
    
    elements.forEach(el => {
        const distance = Math.abs(el.offsetTop - currentScroll);
        if (distance < closestDistance) {
            closestDistance = distance;
            closestElement = el;
        }
    });
    
    if (closestElement && closestElement.id) {
        lastKnownPosition.elementId = closestElement.id;
        lastKnownPosition.elementOffset = currentScroll - closestElement.offsetTop;
    }
    
    // Send position data to Swift
    window.webkit.messageHandlers.pageInfoHandler.postMessage({
        progress: lastKnownPosition.percentage,
        currentPage: Math.floor(lastKnownPosition.percentage * 100) + 1,
        totalPages: 100,
        pixelOffset: lastKnownPosition.pixelOffset,
        elementId: lastKnownPosition.elementId,
        elementOffset: lastKnownPosition.elementOffset
    });
}

// Enhanced restoration function
function restoreScrollPosition(data) {
    // First try exact pixel position
    if (data.pixelOffset && data.pixelOffset > 0) {
        window.scrollTo(0, data.pixelOffset);
        console.log('Restored to exact pixel offset: ' + data.pixelOffset);
        return;
    }
    
    // Next try element-based position if available
    if (data.elementId) {
        const element = document.getElementById(data.elementId);
        if (element) {
            const targetPosition = element.offsetTop + (data.elementOffset || 0);
            window.scrollTo(0, targetPosition);
            console.log('Restored using element position: ' + targetPosition);
            return;
        }
    }
    
    // Fall back to percentage-based as last resort
    const content = document.getElementById('content');
    if (content && data.percentage) {
        const maxScroll = content.scrollHeight - window.innerHeight;
        const targetPosition = maxScroll * data.percentage;
        window.scrollTo(0, targetPosition);
        console.log('Restored using percentage: ' + data.percentage);
    }
}

// Make the function globally available
window.restoreScrollPosition = restoreScrollPosition;

// Modified scrollToProgress
function scrollToProgress(progress, savedPixelOffset, elementId, elementOffset) {
    // Create a data object with all available positioning info
    const positionData = {
        percentage: progress,
        pixelOffset: savedPixelOffset || 0,
        elementId: elementId || null,
        elementOffset: elementOffset || 0
    };
    
    // Use the enhanced restoration function
    restoreScrollPosition(positionData);
    
    // After scrolling, update progress tracking
    setTimeout(function() {
        trackPosition();
        console.log('Progress restoration complete');
    }, 100);
}

// Function to find the element at a specific character position
function findElementAtCharPosition(targetPosition) {
    const content = document.getElementById('content');
    if (!content) return null;
    
    const textContent = content.textContent;
    if (targetPosition <= 0 || targetPosition >= textContent.length) {
        return null;
    }
    
    // Get all text nodes in order
    let textNodes = [];
    
    function collectTextNodes(node) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (node.textContent.trim().length > 0) {
                textNodes.push(node);
            }
        } else {
            for (let i = 0; i < node.childNodes.length; i++) {
                collectTextNodes(node.childNodes[i]);
            }
        }
    }
    
    collectTextNodes(content);
    
    // Find the text node that contains our target position
    let currentPosition = 0;
    let targetNode = null;
    let positionWithinNode = 0;
    
    for (let i = 0; i < textNodes.length; i++) {
        const nodeLength = textNodes[i].textContent.length;
        
        if (currentPosition + nodeLength >= targetPosition) {
            targetNode = textNodes[i];
            positionWithinNode = targetPosition - currentPosition;
            break;
        }
        
        currentPosition += nodeLength;
    }
    
    if (!targetNode) return null;
    
    // Return the parent element of the text node
    return {
        element: targetNode.parentElement,
        characterOffset: positionWithinNode,
        totalNodeChars: targetNode.textContent.length
    };
}

// Function to scroll to a specific character position
function scrollToCharacterPosition(charPosition) {
    // Store all debug values
    let debug = {};
    
    // Force check vertical mode on each call
    const isVerticalMode = document.body.classList.contains('vertical-text');
    debug.isVerticalMode = isVerticalMode;
    debug.charPosition = charPosition;
    
    const content = document.getElementById('content');
    if (!content) {
        console.log("DEBUG: Content element not found");
        return false;
    }
    
    const totalChars = content.textContent.length;
    debug.totalChars = totalChars;
    
    const ratio = charPosition / totalChars;
    debug.ratio = ratio;
    
    if (isVerticalMode) {
        // For vertical text (horizontal scrolling)
        console.log("DEBUG: Using horizontal scrolling for vertical text");
        
        // Get scroll dimensions
        const scrollWidth = document.documentElement.scrollWidth;
        const viewportWidth = window.innerWidth;
        const maxScrollX = scrollWidth - viewportWidth;
        debug.scrollWidth = scrollWidth;
        debug.viewportWidth = viewportWidth;
        debug.maxScrollX = maxScrollX;
        
        // Important: Calculate target position with negative value
        // Since scrolling from right to left means negative scrollX values
        const targetX = Math.round(-maxScrollX * ratio);
        debug.targetX = targetX;
        
        console.log("DEBUG: Target horizontal scroll: " + targetX + "px of " + maxScrollX + "px");
        
        // Use the more reliable scrollTo with options object
        window.scrollTo({
            left: targetX,
            top: 0,
            behavior: 'auto'
        });
        
        console.log("DEBUG: Applied window.scrollTo with options, targetX: " + targetX);
        
        // Double-check scrolling worked
        setTimeout(() => {
            if (Math.abs(window.scrollX - targetX) > 5) {
                // Try again with a different method
                document.documentElement.scrollLeft = targetX;
                window.scroll(targetX, 0);
            }
        }, 50);
        
        // Check the result for debugging
        debug.afterScrollX = window.scrollX;
        debug.afterScrollLeft1 = document.documentElement.scrollLeft;
        debug.afterScrollLeft2 = document.body.scrollLeft;
    } else {
        // For horizontal text (vertical scrolling)
        console.log("DEBUG: Using vertical scrolling for horizontal text");
        
        const scrollHeight = document.documentElement.scrollHeight;
        const viewportHeight = window.innerHeight;
        const maxScrollY = scrollHeight - viewportHeight;
        debug.scrollHeight = scrollHeight;
        debug.viewportHeight = viewportHeight;
        debug.maxScrollY = maxScrollY;
        
        const targetY = Math.round(maxScrollY * ratio);
        debug.targetY = targetY;
        
        console.log("DEBUG: Target vertical scroll: " + targetY + "px of " + maxScrollY + "px");
        
        window.scrollTo(0, targetY);
        console.log("DEBUG: Applied window.scrollTo(0, " + targetY + ")");
        
        debug.afterScrollY = window.scrollY;
        console.log("DEBUG: After scroll - window.scrollY: " + window.scrollY);
    }
    
    // Return full debug info
    return debug;
}

function getCurrentCharacterPosition() {
    const content = document.getElementById('content');
    if (!content) return { explored: 0, total: 0 };
    
    const totalChars = content.textContent.length;
    
    // Detect if we're in vertical mode
    const isVerticalMode = document.body.classList.contains('vertical-text');
    
    let ratio;
    if (isVerticalMode) {
        // For vertical text (horizontal scrolling)
        const scrollX = window.scrollX;
        const scrollWidth = document.documentElement.scrollWidth - window.innerWidth;
        ratio = scrollWidth > 0 ? scrollX / scrollWidth : 0;
    } else {
        // For horizontal text (vertical scrolling)
        const scrollY = window.scrollY;
        const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
        ratio = scrollHeight > 0 ? scrollY / scrollHeight : 0;
    }
    
    // Calculate character count
    const exploredChars = Math.round(totalChars * ratio);
    
    return {
        explored: exploredChars,
        total: totalChars,
        ratio: ratio,
        isVerticalMode: isVerticalMode
    };
}
// Utility to handle font size changes with exact character position preservation
function changeFontSizePreservingCharPosition(fontSize, charPosition) {
    // Save exact character position
    const position = charPosition || getCurrentCharacterPosition().explored;
    
    // Update font size
    document.documentElement.style.setProperty('--shiori-font-size', fontSize + 'px');
    
    // Give browser time to update layout
    setTimeout(() => {
        // Scroll to the saved character position
        scrollToCharacterPosition(position);
        console.log('Restored to exact character position:', position);
    }, 50);
}

function debugVerticalScrolling(charPosition) {
    // Collect detailed info about the current state
    const content = document.getElementById('content');
    const isVerticalMode = document.body.classList.contains('vertical-text');
    const bodyClasses = document.body.className;
    
    // Get all computed style information
    const bodyStyles = window.getComputedStyle(document.body);
    const htmlStyles = window.getComputedStyle(document.documentElement);
    
    // Get current scroll positions and dimensions
    const scrollX = window.scrollX;
    const scrollY = window.scrollY;
    const scrollWidth = document.documentElement.scrollWidth;
    const scrollHeight = document.documentElement.scrollHeight;
    const clientWidth = document.documentElement.clientWidth;
    const clientHeight = document.documentElement.clientHeight;
    
    // Check content dimensions
    const contentRect = content ? content.getBoundingClientRect() : null;
    const contentWidth = contentRect ? contentRect.width : 0;
    const contentHeight = contentRect ? contentRect.height : 0;
    
    // Check writing mode and text orientation
    const writingMode = bodyStyles.writingMode;
    const textOrientation = bodyStyles.textOrientation;
    
    // Check overflow settings
    const overflowX = bodyStyles.overflowX;
    const overflowY = bodyStyles.overflowY;
    
    // Calculate what the scroll position should be
    const totalChars = content ? content.textContent.length : 0;
    const ratio = charPosition / totalChars;
    const expectedHorizontalScroll = (scrollWidth - clientWidth) * ratio;
    
    // Return all debug information
    return {
        debug: "Vertical Scrolling Debug",
        charPosition: charPosition,
        isVerticalMode: isVerticalMode,
        bodyClasses: bodyClasses,
        writingMode: writingMode,
        textOrientation: textOrientation,
        scrollX: scrollX,
        scrollY: scrollY,
        scrollWidth: scrollWidth,
        scrollHeight: scrollHeight,
        clientWidth: clientWidth,
        clientHeight: clientHeight,
        contentWidth: contentWidth,
        contentHeight: contentHeight,
        overflowX: overflowX,
        overflowY: overflowY,
        totalChars: totalChars,
        ratio: ratio,
        expectedHorizontalScroll: expectedHorizontalScroll
    };
}
