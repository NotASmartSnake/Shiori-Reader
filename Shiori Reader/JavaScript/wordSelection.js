// wordSelection.js - Enhanced version with proper ruby handling and improved tap reliability

// Store references to our event listeners for later cleanup
let documentClickListener = null;

// Cleanup function that will be exposed globally
window.shioriCleanupEventListeners = function() {
    if (documentClickListener) {
        document.removeEventListener('click', documentClickListener);
    }
    // Reset the reference
    documentClickListener = null;
    
    // Return true to indicate successful cleanup
    return true;
};

// Function to safely send logs
function shioriLog(message) {
    // Use console log first (always works)
    console.log("[Shiori] " + message);
    
    // Then try to use our handler if available
    try {
        const handlerName = window.shioriLogHandlerName || "shioriLog";
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName]) {
            window.webkit.messageHandlers[handlerName].postMessage(message);
        }
    } catch(e) {
        console.log("[Shiori] Error sending log: " + e);
    }
}

// shioriLog("Script initialized");

// Pattern to detect Japanese text
const japanesePattern = /[\u3000-\u303F]|[\u3040-\u309F]|[\u30A0-\u30FF]|[\uFF00-\uFFEF]|[\u4E00-\u9FAF]|[\u2605-\u2606]|[\u2190-\u2195]|\u203B/g;

// Helper function to dismiss dictionary
function dismissDictionary() {
    try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dismissDictionary) {
            window.webkit.messageHandlers.dismissDictionary.postMessage({});
            return true;
        }
        return false;
    } catch(e) {
        // shioriLog("Error dismissing dictionary: " + e);
        return false;
    }
}

// Helper function to check if point is within bounding box
function bboxIncludesPoint(bbox, point, margin = 0) {
    return point.x >= bbox.left - margin &&
           point.x <= bbox.right + margin &&
           point.y >= bbox.top - margin &&
           point.y <= bbox.bottom + margin;
}

// Improved caretRangeFromPoint that checks previous character bbox
function getImprovedCaretPosition(point) {
    let range = document.caretRangeFromPoint(point.x, point.y);
    if (!range) {
        return null;
    }
    
    // Apply the fix for character selection precision
    // If the cursor is more than half way across a character,
    // caretRangeFromPoint will choose the *next* character since that's where
    // the cursor would be placed if you clicked there and started editing the
    // text.
    //
    // For *looking up* text, however, it's more intuitive if we look up starting
    // from the character you're pointing at.
    //
    // Below we see if the point is within the bounding box of the *previous*
    // character in the inline direction and, if it is, start from there instead.
    
    const { startContainer, startOffset } = range;
    if (startContainer.nodeType === Node.TEXT_NODE && startOffset > 0) {
        const previousCharRange = new Range();
        previousCharRange.setStart(startContainer, startOffset - 1);
        previousCharRange.setEnd(startContainer, startOffset);
        
        const previousCharacterBbox = previousCharRange.getBoundingClientRect();
        if (bboxIncludesPoint(previousCharacterBbox, point)) {
            // The click was actually on the previous character
            range = new Range();
            range.setStart(startContainer, startOffset - 1);
            range.setEnd(startContainer, startOffset - 1);
        }
    }
    
    return range;
}

// Define the click handler function
documentClickListener = function(event) {
    // shioriLog("Click detected at " + event.clientX + "," + event.clientY);
    
    // Skip interactive elements
    if (event.target.tagName === 'A' ||
        event.target.tagName === 'BUTTON' ||
        event.target.tagName === 'INPUT' ||
        event.target.closest('a') ||
        event.target.closest('button')) {
        // shioriLog("Skipping interactive element");
        dismissDictionary();
        return;
    }
    
    // Special handling for ruby elements
    const rubyElement = event.target.tagName === 'RUBY' ?
                        event.target :
                        event.target.closest('ruby');
                        
    if (rubyElement) {
        // shioriLog("Ruby element detected, handling specially");
        handleRubyClick(event, rubyElement);
        return;
    }
    
    // Standard text node handling for non-ruby elements using improved caret position
    let range = getImprovedCaretPosition({x: event.clientX, y: event.clientY});
    if (!range) {
        // shioriLog("No text range found at click point");
        dismissDictionary();
        return;
    }
    
    // shioriLog("Text node found, looking for Japanese text");
    
    let node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE) {
        dismissDictionary();
        return;
    }
    
    let text = node.textContent;
    let offset = range.startOffset;
    
    if (offset < text.length) {
        let contextText = text.substring(offset, Math.min(text.length, offset + 30));
        // shioriLog("Text at click: " + contextText);
        
        // Check for Japanese text
        if (japanesePattern.test(contextText)) {
            // shioriLog("Japanese text found");
            
            // Get surrounding sentence for better context
            const surroundingText = getExtendedSurroundingText(node.parentNode, contextText, 250);
            
            // Always provide paragraph-level context for character picker consistency
            let paragraph = node.parentNode;
            let searchDepth = 0;
            const maxDepth = 10;
            
            // Find the paragraph or chapter container
            while (paragraph && searchDepth < maxDepth && 
                   paragraph.tagName !== 'P' && 
                   !paragraph.classList.contains('chapter-content') && 
                   !paragraph.classList.contains('chapter')) {
                paragraph = paragraph.parentNode;
                searchDepth++;
                if (paragraph === document.body || !paragraph) {
                    paragraph = node.parentNode;
                    break;
                }
            }
            
            // Get clean paragraph text (without furigana)
            const cleanParagraphText = getTextWithoutFurigana(paragraph);
            
            // Calculate the offset of the clicked text within the clean paragraph
            let absoluteOffset = 0;
            try {
                // Calculate base offset of the text node within the paragraph
                const baseOffset = calculateCleanOffsetOfElement(node, paragraph);
                absoluteOffset = baseOffset + offset;
                
                // Verify the offset makes sense
                if (absoluteOffset >= 0 && absoluteOffset < cleanParagraphText.length) {
                    const charAtOffset = cleanParagraphText[absoluteOffset];
                    
                    if (charAtOffset !== contextText[0]) {
                        // Try to find the correct offset by searching
                        const expectedChar = contextText[0];
                        for (let i = Math.max(0, absoluteOffset - 10); i < Math.min(cleanParagraphText.length, absoluteOffset + 10); i++) {
                            if (cleanParagraphText[i] === expectedChar) {
                                absoluteOffset = i;
                                break;
                            }
                        }
                    }
                } else {
                    // shioriLog(`⚠️ WARNING: Calculated offset ${absoluteOffset} is out of bounds for text length ${cleanParagraphText.length}`);
                }
            } catch (error) {
                // shioriLog(`Error calculating offset, using simple offset: ${error}`);
                absoluteOffset = offset;
            }
                        
            // Send to Swift with paragraph context
            sendWordToSwift(contextText, {
                absoluteOffset: absoluteOffset,
                surroundingText: surroundingText,
                fullText: cleanParagraphText, // Always use paragraph context
                rawFullText: paragraph.textContent
            });
        } else {
            // shioriLog("No Japanese text found in: " + contextText);
            dismissDictionary();
        }
    } else {
        dismissDictionary();
    }
};

// Register the click event listener
document.addEventListener('click', documentClickListener, false);

// Ruby handling functions with improved unified context handling
function handleRubyClick(event, rubyElement) {
    // Get all rb elements within this ruby element
    const rbElements = rubyElement.querySelectorAll('rb');
    
    // Get all RT elements for readings
    const rtElements = rubyElement.querySelectorAll('rt');
    
    // First, try to determine what was actually clicked using improved caret position
    const range = getImprovedCaretPosition({x: event.clientX, y: event.clientY});
    if (!range) {
        handleFullRubySelection(rubyElement);
        return;
    }
    
    const clickedNode = range.startContainer;
    
    // Find what element contains the clicked node
    let containingElement = clickedNode;
    if (clickedNode.nodeType === Node.TEXT_NODE) {
        containingElement = clickedNode.parentNode;
    }
    
    // Determine if this is RT (reading) or base text
    const isRtElement = containingElement.tagName === 'RT' ||
                       (containingElement.parentNode && containingElement.parentNode.tagName === 'RT');
    
    // If user clicked on reading (RT), find the corresponding base character
    if (isRtElement) {
        // Find index of this RT among all RTs
        const allRts = Array.from(rubyElement.querySelectorAll('rt'));
        const clickedRtIndex = allRts.findIndex(rt => rt === containingElement || rt.contains(containingElement));
        
        // Get corresponding base text
        if (rbElements.length > 0 && clickedRtIndex >= 0 && clickedRtIndex < rbElements.length) {
            // For explicit rb elements
            const correspondingRb = rbElements[clickedRtIndex];
            
            // Now use the corresponding base text for lookup with unified context
            processTappedRubyTextUnified(
                correspondingRb.textContent,
                rtElements[clickedRtIndex].textContent,
                rubyElement,
                0 // Start of the ruby element
            );
            return;
        } else {
            // For implicit ruby, it's harder to determine
            handleFullRubySelectionUnified(rubyElement);
            return;
        }
    }
    
    // Get the text content of the ruby element - PROPERLY WITHOUT FURIGANA
    const baseText = getFullRubyBaseText(rubyElement);
    
    // If we have explicit rb elements
    if (rbElements.length > 0) {
        // We have explicit rb elements, determine which one was clicked
        const clickedRb = determineClickedElement(event, [...rbElements]);
        
        if (clickedRb) {
            processTappedExplicitRubyTextUnified(clickedRb, rubyElement);
            return;
        }
    } else {
        // Implicit ruby without rb elements
        
        // Map click position to character position visually
        const rubyRect = rubyElement.getBoundingClientRect();
        const relativeX = event.clientX - rubyRect.left;
        
        // Calculate approximate character position based on relative click position
        const clickRatio = relativeX / rubyRect.width;
        const charPosition = Math.floor(clickRatio * baseText.length);
        const adjustedPosition = Math.min(Math.max(0, charPosition), baseText.length - 1);
        
        // Use unified processing
        processTappedRubyTextUnified(
            baseText,
            getFullRubyReading(rubyElement),
            rubyElement,
            adjustedPosition
        );
        
        return;
    }
    
    // Fallback to using the full ruby content
    handleFullRubySelectionUnified(rubyElement);
}

// UNIFIED RUBY PROCESSING FUNCTIONS
// These functions provide consistent context and offset calculation for all ruby interactions

// Get the paragraph containing an element and calculate consistent offsets
function getUnifiedContextForElement(element) {
    // Find the containing paragraph
    let paragraph = element;
    while (paragraph && paragraph.tagName !== 'P' && !paragraph.classList.contains('chapter-content') && !paragraph.classList.contains('chapter')) {
        paragraph = paragraph.parentNode;
        if (paragraph === document.body || !paragraph) {
            // Fallback: use a parent that contains text
            paragraph = element.closest('div, p, section, article') || element.parentNode;
            break;
        }
    }
    
    if (!paragraph) {
        paragraph = element.parentNode || element;
    }
    
    // Get the clean text of the entire paragraph (without furigana)
    const cleanParagraphText = getTextWithoutFurigana(paragraph);
    
    // Calculate the offset of the element within the clean paragraph text
    const elementOffset = calculateCleanOffsetOfElement(element, paragraph);
    
    return {
        cleanParagraphText: cleanParagraphText,
        elementOffset: elementOffset,
        paragraph: paragraph
    };
}

// FIXED: Calculate the offset of an element within the cleaned text of its container
function calculateCleanOffsetOfElement(targetElement, containerElement) {
    let offset = 0;
    
    // Safety check to prevent infinite recursion
    if (!targetElement || !containerElement || targetElement === containerElement) {
        // shioriLog(`Safety check failed: targetElement=${!!targetElement}, containerElement=${!!containerElement}, same=${targetElement === containerElement}`);
        return 0;
    }
    
    // shioriLog(`🔧 OFFSET CALC START: Target=${targetElement.tagName || 'TEXT'}, Container=${containerElement.tagName}`);
    
    // First, let's try a different approach - manually walk through nodes
    // and build the clean text while tracking our target
    function walkAndCount(node, target) {
        let currentOffset = 0;
        let found = false;
        
        // shioriLog(`🔍 Starting walkAndCount for target in container`);
        
        function processNode(currentNode, depth = 0) {
            // If we found our target, stop
            if (found) return;
            
            const indent = '  '.repeat(depth);
            // shioriLog(`${indent}Processing node: ${currentNode.nodeType === Node.TEXT_NODE ? 'TEXT' : currentNode.tagName || 'UNKNOWN'} - offset: ${currentOffset}`);
            
            // Check if this is our target
            if (currentNode === target) {
                found = true;
                // shioriLog(`${indent}🎯 FOUND TARGET at offset ${currentOffset}`);
                return;
            }
            
            // Process based on node type
            if (currentNode.nodeType === Node.TEXT_NODE) {
                // For text nodes, check if they contain our target
                if (target.nodeType === Node.TEXT_NODE && currentNode === target) {
                    found = true;
                    // shioriLog(`${indent}🎯 FOUND TARGET TEXT NODE at offset ${currentOffset}`);
                    return;
                }
                
                // Add text length if this isn't inside RT/RP
                let parent = currentNode.parentNode;
                let insideRubyReading = false;
                while (parent && parent !== containerElement) {
                    if (parent.tagName === 'RT' || parent.tagName === 'RP') {
                        insideRubyReading = true;
                        break;
                    }
                    parent = parent.parentNode;
                }
                
                if (!insideRubyReading) {
                    const textLength = currentNode.textContent.length;
                    currentOffset += textLength;
                    // shioriLog(`${indent}📝 Added text node (length=${textLength}): "${currentNode.textContent.substring(0, 20)}..." -> offset=${currentOffset}`);
                } else {
                    // shioriLog(`${indent}⏭️ Skipping text node inside RT/RP: "${currentNode.textContent.substring(0, 20)}..."`);
                }
            }
            else if (currentNode.nodeType === Node.ELEMENT_NODE) {
                if (currentNode.tagName === 'RT' || currentNode.tagName === 'RP') {
                    // Skip RT and RP elements entirely
                    // shioriLog(`${indent}⏭️ Skipping ${currentNode.tagName} element`);
                    return;
                }
                else if (currentNode.tagName && currentNode.tagName.toUpperCase() === 'RUBY') {
                    // shioriLog(`${indent}💎 Processing RUBY element`);
                    
                    // Check if our target is inside this ruby
                    if (currentNode.contains(target)) {
                        // shioriLog(`${indent}💎 This RUBY contains our target`);
                        
                        // We need to count characters within this ruby up to our target
                        // Get the base text without furigana
                        const rubyBaseText = getFullRubyBaseText(currentNode);
                        // shioriLog(`${indent}💎 Ruby base text: "${rubyBaseText}"`);
                        
                        // Check if we have explicit rb elements
                        const rbElements = currentNode.querySelectorAll('rb');
                        
                        if (rbElements.length > 0) {
                            // shioriLog(`${indent}💎 Found ${rbElements.length} RB elements`);
                            // Explicit rb structure - count rb elements until we find our target
                            for (let i = 0; i < rbElements.length; i++) {
                                const rb = rbElements[i];
                                const rbText = cleanRubyText(rb.textContent);
                                // shioriLog(`${indent}💎 Processing RB[${i}]: "${rbText}"`);
                                
                                if (rb.contains(target) || rb === target) {
                                    // shioriLog(`${indent}💎 Target found in RB[${i}]`);
                                    
                                    if (target.nodeType === Node.TEXT_NODE && rb.contains(target)) {
                                        // Target is a text node within this rb
                                        // We need to find the offset within this rb
                                        let rbOffset = 0;
                                        for (const child of rb.childNodes) {
                                            if (child === target) {
                                                currentOffset += rbOffset;
                                                found = true;
                                                // shioriLog(`${indent}🎯 FOUND TARGET within RB at offset ${currentOffset}`);
                                                return;
                                            }
                                            if (child.nodeType === Node.TEXT_NODE) {
                                                rbOffset += child.textContent.length;
                                            }
                                        }
                                    } else {
                                        // Target is the rb element itself or direct text
                                        currentOffset += rbText.length;
                                        found = true;
                                        // shioriLog(`${indent}🎯 FOUND TARGET RB at offset ${currentOffset}`);
                                        return;
                                    }
                                    break;
                                } else {
                                    // This rb comes before our target, count its characters
                                    currentOffset += rbText.length;
                                    // shioriLog(`${indent}💎 Added previous RB[${i}] (length=${rbText.length}): "${rbText}" -> offset=${currentOffset}`);
                                }
                            }
                        } else {
                            // shioriLog(`${indent}💎 Implicit ruby structure, processing text nodes`);
                            // Implicit ruby structure - need to process text nodes directly
                            for (const child of currentNode.childNodes) {
                                if (child.nodeType === Node.ELEMENT_NODE && 
                                    (child.tagName === 'RT' || child.tagName === 'RP')) {
                                    // Skip RT and RP elements
                                    // shioriLog(`${indent}💎 Skipping ${child.tagName} in implicit ruby`);
                                    continue;
                                }
                                
                                if (child === target) {
                                    found = true;
                                    // shioriLog(`${indent}🎯 FOUND TARGET in implicit ruby at offset ${currentOffset}`);
                                    return;
                                }
                                
                                if (child.nodeType === Node.TEXT_NODE) {
                                    if (child === target) {
                                        found = true;
                                        // shioriLog(`${indent}🎯 FOUND TARGET TEXT in implicit ruby at offset ${currentOffset}`);
                                        return;
                                    }
                                    currentOffset += child.textContent.length;
                                    // shioriLog(`${indent}💎 Added implicit ruby text (length=${child.textContent.length}): "${child.textContent}" -> offset=${currentOffset}`);
                                }
                            }
                        }
                        
                        if (!found) {
                            // shioriLog(`${indent}⚠️ Target not found within ruby, this shouldn't happen`);
                        }
                        return; // Don't process children again
                    } else {
                        // This ruby doesn't contain our target, so just add its base text length
                        const rubyBaseText = getFullRubyBaseText(currentNode);
                        const rubyLength = rubyBaseText.length;
                        currentOffset += rubyLength;
                        // shioriLog(`${indent}💎 Added complete ruby element (length=${rubyLength}): "${rubyBaseText}" -> offset=${currentOffset}`);
                        return; // CRITICAL: Don't process children - we've already counted the base text
                    }
                }
                
                // For other elements, process children
                // shioriLog(`${indent}Processing children of ${currentNode.tagName}`);
                for (const child of currentNode.childNodes) {
                    processNode(child, depth + 1);
                    if (found) return;
                }
            }
        }
        
        // Start processing from container's children
        for (const child of node.childNodes) {
            processNode(child);
            if (found) break;
        }
        
        return currentOffset;
    }
    
    const result = walkAndCount(containerElement, targetElement);
    // shioriLog(`🏁 FINAL OFFSET: ${result}`);
    return result;
}

// Unified function to process tapped ruby text
function processTappedRubyTextUnified(baseText, reading, rubyElement, rubyInternalOffset) {
    // Clean base text to ensure no furigana
    baseText = cleanRubyText(baseText);
    
    // Get paragraph context the same way as regular text
    let paragraph = rubyElement.parentNode;
    let searchDepth = 0;
    const maxDepth = 10;
    
    // Find the paragraph or chapter container
    while (paragraph && searchDepth < maxDepth && 
           paragraph.tagName !== 'P' && 
           !paragraph.classList.contains('chapter-content') && 
           !paragraph.classList.contains('chapter')) {
        paragraph = paragraph.parentNode;
        searchDepth++;
        if (paragraph === document.body || !paragraph) {
            paragraph = rubyElement.parentNode;
            break;
        }
    }
    
    // Get clean paragraph text (without furigana)
    const cleanParagraphText = getTextWithoutFurigana(paragraph);
    
    // Calculate the absolute offset within the paragraph
    let absoluteOffset = 0;
    try {
        absoluteOffset = calculateCleanOffsetOfElement(rubyElement, paragraph) + rubyInternalOffset;
    } catch (error) {
        // shioriLog(`Error calculating ruby offset: ${error}`);
        absoluteOffset = rubyInternalOffset;
    }
    
    // Get extended surrounding text for better context
    const surroundingText = getExtendedSurroundingText(rubyElement, baseText, 250);
    
    // Get the text to search from the clicked position for dictionary lookup
    const searchText = cleanParagraphText.substring(absoluteOffset);
    
    // shioriLog(`Ruby context: baseText='${baseText}', cleanText length=${cleanParagraphText.length}, absoluteOffset=${absoluteOffset}`);
    
    // Send the search text for dictionary lookup, but provide paragraph context for character picker
    sendWordToSwift(searchText, {
        reading: reading,
        surroundingText: surroundingText,
        fullText: cleanParagraphText, // Same paragraph context as regular text
        absoluteOffset: absoluteOffset, // Absolute position in paragraph
        rawFullText: paragraph.textContent,
        isRuby: true,
        isPartialCompound: false
    });
}

// Unified function to process explicit ruby text with rb elements
function processTappedExplicitRubyTextUnified(clickedRb, rubyElement) {
    // Get the clicked kanji (clean it to ensure no furigana)
    const kanji = cleanRubyText(clickedRb.textContent);
    
    // Find the corresponding rt element (reading)
    let reading = '';
    const rbElements = rubyElement.querySelectorAll('rb');
    const rbIndex = [...rbElements].indexOf(clickedRb);
    const rtElements = rubyElement.querySelectorAll('rt');
    
    if (rtElements.length > rbIndex) {
        reading = rtElements[rbIndex].textContent.trim();
    }
    
    // Calculate the character offset within the ruby compound
    let rubyInternalOffset = 0;
    for (let i = 0; i < rbIndex; i++) {
        rubyInternalOffset += cleanRubyText(rbElements[i].textContent).length;
    }
    
    // Use the unified processing
    processTappedRubyTextUnified(kanji, reading, rubyElement, rubyInternalOffset);
}

// Unified function to handle full ruby selection
function handleFullRubySelectionUnified(rubyElement) {
    // Get the full ruby content (properly cleaned)
    const fullBaseText = getFullRubyBaseText(rubyElement);
    const fullReading = getFullRubyReading(rubyElement);
    
    // Use unified processing starting from the beginning of the ruby
    processTappedRubyTextUnified(fullBaseText, fullReading, rubyElement, 0);
}

// Function to process tapped ruby text
function processTappedRubyText(baseText, reading, rubyElement) {
    // Clean base text to ensure no furigana
    baseText = cleanRubyText(baseText);
    
    // Get text after this ruby element
    const textAfterRuby = getTextAfterElement(rubyElement, 30);
    
    // Combined text starting with the base text
    const extendedText = baseText + textAfterRuby;
    
    // Get extended surrounding text for better context
    const surroundingText = getExtendedSurroundingText(rubyElement, baseText, 250);
    
    sendWordToSwift(extendedText, {
        reading: reading,
        surroundingText: surroundingText,
        fullText: extendedText, // Full context for character picker
        absoluteOffset: 0, // Start from beginning of ruby text
        isRuby: true,
        isPartialCompound: false
    });
}

// Process a tapped explicit ruby text (with rb elements)
function processTappedExplicitRubyText(clickedRb, rubyElement) {
    // Get the clicked kanji (clean it to ensure no furigana)
    const kanji = cleanRubyText(clickedRb.textContent);
    
    // Find the corresponding rt element (reading)
    let reading = '';
    const rbElements = rubyElement.querySelectorAll('rb');
    const rbIndex = [...rbElements].indexOf(clickedRb);
    const rtElements = rubyElement.querySelectorAll('rt');
    
    if (rtElements.length > rbIndex) {
        reading = rtElements[rbIndex].textContent.trim();
    }
    
    // Get the full compound for context (clean all rb elements)
    const fullRubyText = [...rbElements].map(rb => cleanRubyText(rb.textContent)).join('');
    const fullReading = [...rtElements].map(rt => rt.textContent).join('');
    
    // Find the character offset within the full compound
    let charOffset = 0;
    for (let i = 0; i < rbIndex; i++) {
        charOffset += cleanRubyText(rbElements[i].textContent).length;
    }
    
    // Get text after ruby element
    const textAfterRuby = getTextAfterElement(rubyElement, 30);
    
    // Build the context for navigation - text from clicked character onwards
    const fullContextText = fullRubyText + textAfterRuby;
    
    // Get the surrounding paragraph context
    const surroundingText = getExtendedSurroundingText(rubyElement, fullRubyText, 250);
    
    sendWordToSwift(fullContextText, {
        reading: reading,
        fullCompound: fullRubyText,
        fullReading: fullReading,
        surroundingText: surroundingText,
        fullText: fullContextText, // Full context for character picker navigation
        absoluteOffset: charOffset, // Offset of clicked character within the ruby compound
        isRuby: true,
        isPartialCompound: true,
        selectedIndex: rbIndex
    });
}

function handleFullRubySelection(rubyElement) {
    // Get the full ruby content (properly cleaned)
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
    const surroundingText = getExtendedSurroundingText(rubyElement, fullBaseText, 250);
    
    sendWordToSwift(extendedText, {
        reading: fullReading,
        textFromClickedKanji: extendedText,  // Include text after ruby
        surroundingText: surroundingText,
        textAfterRuby: textAfterRuby,
        fullText: extendedText, // Full context for character picker
        absoluteOffset: 0, // Start from beginning since full ruby selected
        isRuby: true
    });
}

// Helper to get all base text parts
function getBaseTextParts(rubyElement, parts) {
    for (const node of rubyElement.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (node.textContent.trim()) {
                parts.push(node);
            }
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            if (node.tagName !== 'RT' && node.tagName !== 'RP') {
                if (node.childNodes.length > 0) {
                    getBaseTextParts(node, parts);
                } else {
                    parts.push(node);
                }
            }
        }
    }
    
    return parts;
}

// Helper to get text after an element
function getTextAfterElement(element, maxLength) {
    let result = '';
    let currentNode = element.nextSibling;
    let textLength = 0;
    
    while (currentNode && textLength < maxLength) {
        if (currentNode.nodeType === Node.TEXT_NODE) {
            result += currentNode.textContent;
            textLength += currentNode.textContent.length;
        } else if (currentNode.nodeType === Node.ELEMENT_NODE &&
                  currentNode.tagName !== 'RT' &&
                  currentNode.tagName !== 'RP') {
            for (const child of currentNode.childNodes) {
                if (child.nodeType === Node.TEXT_NODE) {
                    result += child.textContent;
                    textLength += child.textContent.length;
                }
            }
        }
        
        if (textLength >= maxLength) break;
        currentNode = currentNode.nextSibling;
    }
    
    return result;
}

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

// Function to get the single sentence containing the selected text
function getExtendedSurroundingText(element, selectedText, maxLength) {
    const sentenceEnders = ['。', '！', '？', '!', '?'];
    
    // First, try to get context from the paragraph containing the element
    const paragraph = element.closest('p, div.chapter-content, div.chapter');
    
    if (paragraph) {
        // Get the text content of the paragraph WITHOUT furigana
        const paragraphText = getTextWithoutFurigana(paragraph);
        
        // Find the selected text in the paragraph
        const selectedIndex = paragraphText.indexOf(selectedText);
        
        if (selectedIndex >= 0) {
            // Determine which sentence contains our selected text
            // First, find all sentence boundaries
            const sentenceBoundaries = [];
            for (let i = 0; i < paragraphText.length; i++) {
                if (sentenceEnders.includes(paragraphText[i])) {
                    sentenceBoundaries.push(i);
                }
            }
            
            // Add the start and end of text as boundaries
            sentenceBoundaries.unshift(-1); // Start of text (will use index+1)
            sentenceBoundaries.push(paragraphText.length - 1); // End of text
            
            // Find which sentence contains our selected text
            let sentenceStart = 0;
            let sentenceEnd = paragraphText.length;
            
            for (let i = 0; i < sentenceBoundaries.length - 1; i++) {
                const startPos = sentenceBoundaries[i] + 1;
                const endPos = sentenceBoundaries[i + 1] + 1;
                
                // Check if selected text is within this sentence
                if (selectedIndex >= startPos && selectedIndex < endPos) {
                    sentenceStart = startPos;
                    sentenceEnd = endPos;
                    break;
                }
            }
            
            // Extract the single sentence
            const sentence = paragraphText.substring(sentenceStart, sentenceEnd).trim();
            
            return sentence;
        }
    }
    
    // Fallback to using just the selected text
    return selectedText;
}

// Helper function to get text content excluding furigana
function getTextWithoutFurigana(element) {
    // Clone the element to avoid modifying the original
    const clone = element.cloneNode(true);
    
    // Remove all RT elements from the clone
    const rtElements = clone.querySelectorAll('rt');
    rtElements.forEach(rt => rt.remove());
    
    // Also remove RP elements (ruby parentheses) if present
    const rpElements = clone.querySelectorAll('rp');
    rpElements.forEach(rp => rp.remove());
    
    // Get the text content of the cleaned clone
    return clone.textContent;
}

// Helper to find which element was clicked based on position
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

// Function to get base text from ruby element WITHOUT furigana
function getFullRubyBaseText(rubyElement) {
    // First try to get text from explicit rb elements
    const rbElements = rubyElement.querySelectorAll('rb');
    if (rbElements.length > 0) {
        // Clean each rb to remove any nested furigana
        return Array.from(rbElements)
            .map(rb => cleanRubyText(rb.textContent))
            .join('');
    }
    
    // Handle implicit base text (direct text nodes or non-rt elements)
    // Create a clone of the ruby element
    const clonedRuby = rubyElement.cloneNode(true);
    
    // Remove all RT and RP elements
    const rtElements = clonedRuby.querySelectorAll('rt');
    rtElements.forEach(rt => rt.remove());
    
    const rpElements = clonedRuby.querySelectorAll('rp');
    rpElements.forEach(rp => rp.remove());
    
    // Now get the text content of the cleaned element
    return clonedRuby.textContent.trim();
}

// Get readings from ruby element
function getFullRubyReading(rubyElement) {
    const rtElements = rubyElement.querySelectorAll('rt');
    return Array.from(rtElements).map(rt => rt.textContent.trim()).join('');
}

// Helper to clean text that might contain furigana
function cleanRubyText(text) {
    // This is a simple filter that tries to remove all hiragana/katakana
    // characters that might be inline with kanji text in ruby notation
    
    // Japanese hiragana and katakana ranges
    const kanaPattern = /[\u3040-\u309F]|[\u30A0-\u30FF]/g;
    
    // For simple cases, just remove all kana characters mixed with kanji
    // This is a basic approach and may not work for all cases
    if (/[\u4E00-\u9FAF]/.test(text) && kanaPattern.test(text)) {
        // If text has both kanji and kana, and it's likely ruby text,
        // try removing all kana
        return text.replace(kanaPattern, '');
    }
    
    // If it doesn't match the pattern, or it's all kana, return as is
    return text.trim();
}

// Utility function to send word data to Swift
function sendWordToSwift(text, options = {}) {
    try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wordTapped) {
            // Combine text with options
            const data = { text, ...options };
            // shioriLog("Sending word to Swift: " + text);
            window.webkit.messageHandlers.wordTapped.postMessage(data);
            return true;
        }
        return false;
    } catch(e) {
        // shioriLog("Error sending word to Swift: " + e);
        return false;
    }
}

// Function to get full context with proper furigana handling
function getFullContextWithFuriganaHandling(textNode, clickOffset) {
    // Get the paragraph containing this text node
    let paragraph = textNode.parentNode;
    while (paragraph && paragraph.tagName !== 'P' && !paragraph.classList.contains('chapter-content')) {
        paragraph = paragraph.parentNode;
        if (paragraph === document.body) {
            paragraph = textNode.parentNode; // Fallback
            break;
        }
    }
    
    if (!paragraph) {
        // Simple fallback
        return {
            fullText: textNode.textContent,
            cleanFullText: textNode.textContent,
            adjustedOffset: clickOffset
        };
    }
    
    // Get both the raw text (with furigana) and clean text (without furigana)
    const rawText = paragraph.textContent;
    const cleanText = getTextWithoutFurigana(paragraph);
    
    // Calculate the position in the clean text that corresponds to the clicked position
    let adjustedOffset = 0;
    
    // Walk through the paragraph's DOM structure to map the clicked position
    // to the correct position in the cleaned text
    const walker = document.createTreeWalker(
        paragraph,
        NodeFilter.SHOW_TEXT,
        {
            acceptNode: function(node) {
                // Skip text nodes inside RT (furigana) elements
                let parent = node.parentNode;
                while (parent && parent !== paragraph) {
                    if (parent.tagName === 'RT' || parent.tagName === 'RP') {
                        return NodeFilter.FILTER_REJECT;
                    }
                    parent = parent.parentNode;
                }
                return NodeFilter.FILTER_ACCEPT;
            }
        }
    );
    
    let currentNode;
    let cumulativeOffset = 0;
    let found = false;
    
    while (currentNode = walker.nextNode()) {
        if (currentNode === textNode) {
            // Found our target node
            adjustedOffset = cumulativeOffset + clickOffset;
            found = true;
            break;
        }
        cumulativeOffset += currentNode.textContent.length;
    }
    
    if (!found) {
        // Fallback: use the click offset as-is
        adjustedOffset = clickOffset;
    }
    
    // Ensure offset is within bounds
    adjustedOffset = Math.min(Math.max(0, adjustedOffset), cleanText.length - 1);
    
    return {
        fullText: rawText,
        cleanFullText: cleanText,
        adjustedOffset: adjustedOffset
    };
}

// Send a ready notification
try {
    sendWordToSwift("WordSelection script ready", { type: "initialization" });
    // shioriLog("Ready notification sent successfully");
} catch(e) {
    // shioriLog("Error sending ready notification: " + e);
}
