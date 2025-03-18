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
    const result = findElementAtCharPosition(charPosition);
    if (!result) {
        console.error('Could not find element at character position: ' + charPosition);
        return false;
    }
    
    console.log('Found element at char position ' + charPosition + ':',
               result.element.tagName,
               'with text starting with "' + result.element.textContent.substring(0, 20) + '..."');
    
    // Scroll the element into view with center alignment
    result.element.scrollIntoView({
        behavior: 'auto',
        block: 'center'
    });
    
    return true;
}

// Improved function to get character position at current scroll position
function getCurrentCharacterPosition() {
    const content = document.getElementById('content');
    if (!content) return { explored: 0, total: 0 };
    
    const totalChars = content.textContent.length;
    const scrollY = window.scrollY;
    const viewportHeight = window.innerHeight;
    const scrollHeight = document.documentElement.scrollHeight;
    const maxScroll = scrollHeight - viewportHeight;
    const ratio = maxScroll > 0 ? scrollY / maxScroll : 0;
    
    // Calculate character count
    const exploredChars = Math.round(totalChars * ratio);
    
    return {
        explored: exploredChars,
        total: totalChars,
        ratio: ratio,
        scrollY: scrollY
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
