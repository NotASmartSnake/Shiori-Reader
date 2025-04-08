// wordSelection.js - Enhanced version with proper ruby handling

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

shioriLog("Script initialized");

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
        shioriLog("Error dismissing dictionary: " + e);
        return false;
    }
}

// Set up click handler
document.addEventListener('click', function(event) {
    shioriLog("Click detected at " + event.clientX + "," + event.clientY);
    
    // Skip interactive elements
    if (event.target.tagName === 'A' ||
        event.target.tagName === 'BUTTON' ||
        event.target.tagName === 'INPUT' ||
        event.target.closest('a') ||
        event.target.closest('button')) {
        shioriLog("Skipping interactive element");
        dismissDictionary();
        return;
    }
    
    // Special handling for ruby elements
    const rubyElement = event.target.tagName === 'RUBY' ?
                        event.target :
                        event.target.closest('ruby');
                        
    if (rubyElement) {
        shioriLog("Ruby element detected, handling specially");
        handleRubyClick(event, rubyElement);
        return;
    }
    
    // Standard text node handling for non-ruby elements
    let range = document.caretRangeFromPoint(event.clientX, event.clientY);
    if (!range) {
        shioriLog("No text range found at click point");
        dismissDictionary();
        return;
    }
    
    shioriLog("Text node found, looking for Japanese text");
    
    let node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE) {
        dismissDictionary();
        return;
    }
    
    let text = node.textContent;
    let offset = range.startOffset;
    
    if (offset < text.length) {
        let contextText = text.substring(offset, Math.min(text.length, offset + 30));
        shioriLog("Text at click: " + contextText);
        
        // Check for Japanese text
        if (japanesePattern.test(contextText)) {
            shioriLog("Japanese text found");
            
            // Get surrounding sentence for better context
            const surroundingText = getExtendedSurroundingText(node.parentNode, contextText, 250);
            
            // Send to Swift
            sendWordToSwift(contextText, {
                absoluteOffset: offset,
                surroundingText: surroundingText
            });
        } else {
            dismissDictionary();
        }
    } else {
        dismissDictionary();
    }
}, false);

// Ruby handling functions with improved handling
function handleRubyClick(event, rubyElement) {
    // Get all rb elements within this ruby element
    const rbElements = rubyElement.querySelectorAll('rb');
    
    // Get all RT elements for readings
    const rtElements = rubyElement.querySelectorAll('rt');
    
    // First, try to determine what was actually clicked
    const range = document.caretRangeFromPoint(event.clientX, event.clientY);
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
            
            // Now use the corresponding base text for lookup
            processTappedRubyText(
                correspondingRb.textContent,
                rtElements[clickedRtIndex].textContent,
                rubyElement
            );
            return;
        } else {
            // For implicit ruby, it's harder to determine
            handleFullRubySelection(rubyElement);
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
            processTappedExplicitRubyText(clickedRb, rubyElement);
            return;
        }
    } else {
        // Implicit ruby without rb elements
        
        // Collect all text nodes and non-RT/RP elements from ruby
        const baseTextParts = [];
        getBaseTextParts(rubyElement, baseTextParts);
        
        // Map click position to character position visually
        // Calculate bounding client rect of ruby element
        const rubyRect = rubyElement.getBoundingClientRect();
        const relativeX = event.clientX - rubyRect.left;
        
        // Calculate approximate character position based on relative click position
        const clickRatio = relativeX / rubyRect.width;
        const charPosition = Math.floor(clickRatio * baseText.length);
        const adjustedPosition = Math.min(Math.max(0, charPosition), baseText.length - 1);
        
        // Extract text from clicked position
        const textFromPosition = baseText.substring(adjustedPosition);
        
        // Get text after ruby
        const textAfterRuby = getTextAfterElement(rubyElement, 30);
        
        // Get reading
        const reading = getFullRubyReading(rubyElement);
        
        // Combine
        const completeContext = textFromPosition + textAfterRuby;
        
        // Get the surrounding sentence for better context
        const surroundingText = getExtendedSurroundingText(rubyElement, baseText, 250);
        
        sendWordToSwift(completeContext, {
            reading: reading,
            fullCompound: baseText,
            surroundingText: surroundingText,
            textAfterRuby: textAfterRuby,
            isRuby: true,
            isPartialCompound: false
        });
        
        return;
    }
    
    // Fallback to using the full ruby content
    handleFullRubySelection(rubyElement);
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
    const fullText = [...rbElements].map(rb => cleanRubyText(rb.textContent)).join('');
    const fullReading = [...rtElements].map(rt => rt.textContent).join('');
    
    // Find the selected index within the full compound
    const selectedIndex = [...rbElements].indexOf(clickedRb);
    
    // Get text from this point onwards
    const textFromClickedKanji = fullText.substring(selectedIndex) + getTextAfterElement(rubyElement, 30);
    
    sendWordToSwift(textFromClickedKanji, {
        reading: reading,
        fullCompound: fullText,
        fullReading: fullReading,
        textFromClickedKanji: textFromClickedKanji,
        surroundingText: textFromClickedKanji,
        isRuby: true,
        isPartialCompound: true,
        selectedIndex: selectedIndex
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
            shioriLog("Sending word to Swift: " + text);
            window.webkit.messageHandlers.wordTapped.postMessage(data);
            return true;
        }
        return false;
    } catch(e) {
        shioriLog("Error sending word to Swift: " + e);
        return false;
    }
}

// Send a ready notification
try {
    sendWordToSwift("WordSelection script ready", { type: "initialization" });
    shioriLog("Ready notification sent successfully");
} catch(e) {
    shioriLog("Error sending ready notification: " + e);
}
