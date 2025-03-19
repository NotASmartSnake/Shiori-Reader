//
//  WordSelection.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/17/25.
//

// Enhanced Ruby Character Selection script with improved implicit ruby handling
document.addEventListener('click', function(event) {
    // Don't intercept clicks on elements that should be interactive
    if (event.target.tagName === 'A' || 
        event.target.tagName === 'BUTTON' || 
        event.target.tagName === 'INPUT') {
        return;
    }
    
    // Special handling for ruby elements
    const rubyElement = event.target.tagName === 'RUBY' ? 
                        event.target : 
                        event.target.closest('ruby');
                        
    if (rubyElement) {
        handleRubyClick(event, rubyElement);
        return;
    }
    
    // Standard text node handling for non-ruby elements
    let range = document.caretRangeFromPoint(event.clientX, event.clientY);
    if (!range) {
        window.webkit.messageHandlers.dismissDictionary.postMessage({});
        return;
    }
    
    let node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE) {
        window.webkit.messageHandlers.dismissDictionary.postMessage({});
        return;
    }
    
    let text = node.textContent;
    let offset = range.startOffset;
    
    if (offset < text.length) {
        let contextText = text.substring(offset, Math.min(text.length, offset + 30));
        
        if (/[\u3000-\u303F]|[\u3040-\u309F]|[\u30A0-\u30FF]|[\uFF00-\uFFEF]|[\u4E00-\u9FAF]|[\u2605-\u2606]|[\u2190-\u2195]|\u203B/g.test(contextText)) {
            window.webkit.messageHandlers.wordTapped.postMessage({
                text: contextText,
                absoluteOffset: offset
            });
        } else {
            window.webkit.messageHandlers.dismissDictionary.postMessage({});
        }
    } else {
        window.webkit.messageHandlers.dismissDictionary.postMessage({});
    }
}, false);

// Get text starting from a node and collecting from siblings
function getTextFromNodeAndFollowing(startNode, maxLength, skipRubyRt = true) {
    let result = '';
    let currentNode = startNode;
    
    // Function to check if a node should be skipped
    function shouldSkipNode(node) {
        if (!node) return true;
        if (skipRubyRt && node.nodeType === Node.ELEMENT_NODE && 
            (node.tagName === 'RT' || node.tagName === 'RP')) {
            return true;
        }
        return false;
    }
    
    // Process the start node itself
    if (!shouldSkipNode(currentNode)) {
        if (currentNode.nodeType === Node.TEXT_NODE) {
            result += currentNode.textContent;
        } else if (currentNode.nodeType === Node.ELEMENT_NODE) {
            // For elements, get text but skip rt/rp
            for (const child of currentNode.childNodes) {
                if (!shouldSkipNode(child)) {
                    if (child.nodeType === Node.TEXT_NODE) {
                        result += child.textContent;
                    } else if (child.nodeType === Node.ELEMENT_NODE && child.tagName === 'RUBY') {
                        // For ruby elements, get only base text
                        result += getFullRubyBaseText(child);
                    } else {
                        result += getTextFromNodeAndFollowing(child, maxLength - result.length, skipRubyRt);
                    }
                }
            }
        }
    }
    
    // Stop if we've collected enough text
    if (result.length >= maxLength) {
        return result.substring(0, maxLength);
    }
    
    // Process siblings
    while (result.length < maxLength && currentNode.nextSibling) {
        currentNode = currentNode.nextSibling;
        if (!shouldSkipNode(currentNode)) {
            if (currentNode.nodeType === Node.TEXT_NODE) {
                result += currentNode.textContent;
            } else if (currentNode.nodeType === Node.ELEMENT_NODE) {
                if (currentNode.tagName === 'RUBY') {
                    // For ruby elements, get only base text
                    result += getFullRubyBaseText(currentNode);
                } else {
                    // For other elements, get all text content, skipping rt/rp
                    result += getTextFromNodeAndFollowing(currentNode, maxLength - result.length, skipRubyRt);
                }
            }
        }
    }
    
    // Look at parent's siblings if needed and if we have a parent
    if (result.length < maxLength && startNode.parentNode && startNode.parentNode.nextSibling) {
        let parentSibling = startNode.parentNode.nextSibling;
        result += getTextFromNodeAndFollowing(parentSibling, maxLength - result.length, skipRubyRt);
    }
    
    // Limit to maxLength
    return result.substring(0, maxLength);
}

function handleRubyClick(event, rubyElement) {
    // Get all rb elements within this ruby element
    const rbElements = rubyElement.querySelectorAll('rb');
    
    // If traditional rb elements aren't used, we need to handle text nodes directly
    if (rbElements.length === 0) {
        // Get all direct text nodes and non-rt elements as implicit rb content
        const childNodes = [...rubyElement.childNodes];
        const baseTextNodes = childNodes.filter(node =>
            node.nodeType === Node.TEXT_NODE ||
            (node.nodeType === Node.ELEMENT_NODE && node.tagName !== 'RT' && node.tagName !== 'RP')
        );
        
        // If we have direct text content, determine which character was clicked
        if (baseTextNodes.length > 0) {
            handleImplicitRubyClick(event, rubyElement, baseTextNodes);
            return;
        }
    } else {
        // We have explicit rb elements, determine which one was clicked
        const clickedRb = determineClickedElement(event, [...rbElements]);
        
        if (clickedRb) {
            // Get the clicked kanji
            const kanji = clickedRb.textContent.trim();
            
            // Find the corresponding rt element (reading)
            let reading = '';
            const rbIndex = [...rbElements].indexOf(clickedRb);
            const rtElements = rubyElement.querySelectorAll('rt');
            if (rtElements.length > rbIndex) {
                reading = rtElements[rbIndex].textContent.trim();
            }
            
            // Get the full compound for context
            const fullText = [...rbElements].map(rb => rb.textContent).join('');
            const fullReading = [...rubyElement.querySelectorAll('rt')].map(rt => rt.textContent).join('');
            
            // Find the selected index within the full compound
            const selectedIndex = [...rbElements].indexOf(clickedRb);
            
            // Get the text from the clicked kanji to the end of the ruby element
            // and then continuing with following text nodes
            let textFromClickedKanji = '';
            if (selectedIndex >= 0) {
                // First get text within this ruby element
                textFromClickedKanji = [...rbElements]
                    .slice(selectedIndex)
                    .map(rb => rb.textContent)
                    .join('');
                
                // Then extend with text from following nodes
                // Get next sibling after this ruby element
                if (rubyElement.nextSibling) {
                    const followingText = getTextFromNodeAndFollowing(rubyElement.nextSibling, 30 - textFromClickedKanji.length);
                    textFromClickedKanji += followingText;
                }
            }
            
            // Get extended surrounding text (up to 30 chars)
            const surroundingText = getExtendedSurroundingText(rubyElement, kanji, 30);
            
            window.webkit.messageHandlers.wordTapped.postMessage({
                text: textFromClickedKanji,                             // The specific kanji clicked
                reading: reading,                        // Reading for this specific kanji
                fullCompound: fullText,                  // The full ruby compound
                fullReading: fullReading,                // Reading for the full compound
                textFromClickedKanji: textFromClickedKanji, // Text from clicked kanji to end of compound + following
                surroundingText: surroundingText,        // More context from surrounding text
                isRuby: true,
                isPartialCompound: true,
                selectedIndex: selectedIndex            // Index of clicked kanji in the compound
            });
            return;
        }
    }
    
    // Fallback: use the full ruby content
    const fullBaseText = getFullRubyBaseText(rubyElement);
    const fullReading = getFullRubyReading(rubyElement);
    
    // Also get extended surrounding text for more context
    const surroundingText = getExtendedSurroundingText(rubyElement, fullBaseText, 30);
    
    window.webkit.messageHandlers.wordTapped.postMessage({
        text: fullBaseText,
        reading: fullReading,
        surroundingText: surroundingText,
        isRuby: true
    });
}

function handleImplicitRubyClick(event, rubyElement, baseTextNodes) {
    // Calculate the total text content
    const fullText = baseTextNodes.map(node => node.textContent).join('');
    
    // Create a range to determine the clicked position
    const range = document.caretRangeFromPoint(event.clientX, event.clientY);
    if (!range) return;
    
    // Get the specific text node that was clicked
    const clickedNode = range.startContainer;
    
    // Check if this is a text node within our base nodes or a descendant
    const isDescendantOfBaseNode = baseTextNodes.some(node =>
        node === clickedNode || (node.contains && node.contains(clickedNode))
    );
    
    if ((clickedNode.nodeType === Node.TEXT_NODE && baseTextNodes.includes(clickedNode)) ||
        isDescendantOfBaseNode) {
        
        // Get the position within this node
        const offset = range.startOffset;
        
        // Get the character at the clicked position
        const clickedChar = clickedNode.textContent.charAt(offset);
        
        // Get the furigana reading (simplistic matching approach)
        const readings = [];
        const rtElements = rubyElement.querySelectorAll('rt');
        for (const rt of rtElements) {
            readings.push(rt.textContent);
        }
        
        // Get text AFTER the clicked position (crucial for compounds)
        let textAfterRuby = '';
        if (rubyElement.nextSibling) {
            // Collect text from next sibling nodes
            let currentNode = rubyElement.nextSibling;
            let textLength = 0;
            const maxLength = 30; // Reasonable context size
            
            while (currentNode && textLength < maxLength) {
                if (currentNode.nodeType === Node.TEXT_NODE) {
                    textAfterRuby += currentNode.textContent;
                    textLength += currentNode.textContent.length;
                } else if (currentNode.nodeType === Node.ELEMENT_NODE &&
                           currentNode.tagName !== 'RT' &&
                           currentNode.tagName !== 'RP') {
                    // Handle nested text nodes in elements
                    for (const child of currentNode.childNodes) {
                        if (child.nodeType === Node.TEXT_NODE) {
                            textAfterRuby += child.textContent;
                            textLength += child.textContent.length;
                        }
                    }
                }
                
                if (textLength >= maxLength) break;
                currentNode = currentNode.nextSibling;
            }
        }
        
        // Also collect any remaining text within the ruby element after the clicked position
        let remainingTextInRuby = '';
        if (offset < clickedNode.textContent.length - 1) {
            remainingTextInRuby = clickedNode.textContent.substring(offset + 1);
        }
        
        // Combine for a coherent context
        const completeContext = clickedChar + remainingTextInRuby + textAfterRuby;
        
        // Send to dictionary lookup
        window.webkit.messageHandlers.wordTapped.postMessage({
            text: completeContext,                      // The specific character clicked
            fullCompound: fullText,                 // The entire ruby text
            reading: readings.join(''),             // Approximate reading
            textFromClickedKanji: completeContext,  // Important: text from clicked char + following text
            textAfterRuby: textAfterRuby,           // Text from nodes after this ruby
            isRuby: true,
            isPartialCompound: true
        });
    } else {
        // Fallback to using the full ruby
        handleFullRubySelection(rubyElement);
    }
}

function handleFullRubySelection(rubyElement) {
    // Get the full ruby content
    const fullBaseText = getFullRubyBaseText(rubyElement);
    const fullReading = getFullRubyReading(rubyElement);
    
    // Get text from nodes after this ruby element
    let textAfterRuby = '';
    if (rubyElement.nextSibling) {
        textAfterRuby = getTextFromNodeAndFollowing(rubyElement.nextSibling, 30);
    }
    
    // Combined text starting with the full ruby
    const extendedText = fullBaseText + textAfterRuby;
    
    // Get extended surrounding text
    const surroundingText = getExtendedSurroundingText(rubyElement, fullBaseText, 30);
    
    window.webkit.messageHandlers.wordTapped.postMessage({
        text: extendedText,
        reading: fullReading,
        textFromClickedKanji: extendedText,  // Include text after ruby
        surroundingText: surroundingText,
        textAfterRuby: textAfterRuby,
        isRuby: true
    });
}

// Get extended surrounding text, looking at parent container too
function getExtendedSurroundingText(rubyElement, selectedText, maxLength) {
    // Start with the parent paragraph or container
    const container = findTextContainer(rubyElement);
    
    if (container && container !== rubyElement) {
        // Get text content of container
        const containerText = getNodeTextContent(container);
        
        // Try to find the selected text in the container
        const index = containerText.indexOf(selectedText);
        if (index >= 0) {
            // Get text from the selected position to end of container
            const endIndex = Math.min(containerText.length, index + maxLength);
            return containerText.substring(index, endIndex);
        }
    }
    
    // Fallback: collect text from ruby and following nodes
    let result = getFullRubyBaseText(rubyElement);
    
    // Add text from following siblings
    if (rubyElement.nextSibling) {
        result += getTextFromNodeAndFollowing(rubyElement.nextSibling, maxLength - result.length);
    }
    
    return result.substring(0, maxLength);
}

// Find the nearest text container (paragraph, div, etc.)
function findTextContainer(element) {
    // Check if the element itself is a good container
    if (isTextContainer(element)) {
        return element;
    }
    
    // Look for a parent that's a good container
    let parent = element.parentNode;
    while (parent && parent.nodeType === Node.ELEMENT_NODE) {
        if (isTextContainer(parent)) {
            return parent;
        }
        parent = parent.parentNode;
    }
    
    // Fallback to the original element
    return element;
}

// Check if an element is a good text container
function isTextContainer(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) {
        return false;
    }
    
    // Common text container tags
    const containerTags = ['P', 'DIV', 'SPAN', 'LI', 'TD', 'TH', 'BLOCKQUOTE', 'ARTICLE', 'SECTION'];
    
    return containerTags.includes(element.tagName);
}

// Helper to extract text content from a node, skipping rt/rp elements
function getNodeTextContent(node) {
    if (!node) return '';
    
    // Skip rt and rp elements
    if (node.nodeType === Node.ELEMENT_NODE &&
        (node.tagName === 'RT' || node.tagName === 'RP')) {
        return '';
    }
    
    // For ruby elements, get only the base text
    if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'RUBY') {
        return getFullRubyBaseText(node);
    }
    
    // For text nodes, return the text content
    if (node.nodeType === Node.TEXT_NODE) {
        return node.textContent;
    }
    
    // For other element nodes, get text content but filter out rt/rp
    if (node.nodeType === Node.ELEMENT_NODE) {
        let text = '';
        for (const child of node.childNodes) {
            text += getNodeTextContent(child);
        }
        return text;
    }
    
    return '';
}

function determineClickedElement(event, elements) {
    if (elements.length === 0) return null;
    
    // Find the element that was clicked or closest to the click
    let closestElement = null;
    let minDistance = Number.MAX_VALUE;
    
    for (const element of elements) {
        const rect = element.getBoundingClientRect();
        
        // Check if click is within this element
        if (event.clientX >= rect.left && 
            event.clientX <= rect.right && 
            event.clientY >= rect.top && 
            event.clientY <= rect.bottom) {
            return element; // Direct hit
        }
        
        // Calculate center of the element
        const centerX = (rect.left + rect.right) / 2;
        const centerY = (rect.top + rect.bottom) / 2;
        
        // Calculate distance to click
        const distance = Math.sqrt(
            Math.pow(event.clientX - centerX, 2) + 
            Math.pow(event.clientY - centerY, 2)
        );
        
        if (distance < minDistance) {
            minDistance = distance;
            closestElement = element;
        }
    }
    
    return closestElement;
}

function getFullRubyBaseText(rubyElement) {
    // Get text from explicit rb elements
    const rbElements = rubyElement.querySelectorAll('rb');
    if (rbElements.length > 0) {
        return Array.from(rbElements).map(rb => rb.textContent).join('');
    }
    
    // Handle implicit base text (direct text nodes or non-rt elements)
    const textNodes = [];
    for (const node of rubyElement.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
            textNodes.push(node.textContent);
        } else if (node.nodeType === Node.ELEMENT_NODE && 
                  node.tagName !== 'RT' && 
                  node.tagName !== 'RP') {
            textNodes.push(node.textContent);
        }
    }
    
    return textNodes.join('').trim();
}

function getFullRubyReading(rubyElement) {
    const rtElements = rubyElement.querySelectorAll('rt');
    return Array.from(rtElements).map(rt => rt.textContent).join('');
}
