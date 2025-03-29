//
//  debugHTML.js
//  Shiori Reader
//
//  Created by Russell Graviet on 3/27/25.
//


function debugHtmlAndCss() {
    // Print HTML structure of the body
    const bodyHtml = document.body.innerHTML.substring(0, 5000); // First 2000 chars
    console.log("BODY HTML STRUCTURE:");
    console.log(bodyHtml);
    
    // Print computed styles for key elements
    console.log("\nCOMPUTED STYLES:");
    
    // Body styles
    const bodyStyles = window.getComputedStyle(document.body);
    console.log("Body styles:");
    console.log("- padding:", 
        bodyStyles.paddingTop, 
        bodyStyles.paddingRight, 
        bodyStyles.paddingBottom, 
        bodyStyles.paddingLeft
    );
    console.log("- margin:", 
        bodyStyles.marginTop, 
        bodyStyles.marginRight, 
        bodyStyles.marginBottom, 
        bodyStyles.marginLeft
    );
    
    // Content div styles
    const content = document.getElementById('content');
    if (content) {
        const contentStyles = window.getComputedStyle(content);
        console.log("\nContent div styles:");
        console.log("- padding:", 
            contentStyles.paddingTop, 
            contentStyles.paddingRight, 
            contentStyles.paddingBottom, 
            contentStyles.paddingLeft
        );
        console.log("- margin:", 
            contentStyles.marginTop, 
            contentStyles.marginRight, 
            contentStyles.marginBottom, 
            contentStyles.marginLeft
        );
    }
    
    // Last chapter styles
    const chapters = document.querySelectorAll('.chapter');
    if (chapters.length > 0) {
        const lastChapter = chapters[chapters.length - 1];
        const lastChapterStyles = window.getComputedStyle(lastChapter);
        console.log("\nLast chapter styles:");
        console.log("- padding:", 
            lastChapterStyles.paddingTop, 
            lastChapterStyles.paddingRight, 
            lastChapterStyles.paddingBottom, 
            lastChapterStyles.paddingLeft
        );
        console.log("- margin:", 
            lastChapterStyles.marginTop, 
            lastChapterStyles.marginRight, 
            lastChapterStyles.marginBottom, 
            lastChapterStyles.marginLeft
        );
    }
    
    // CSS rules inspection
    console.log("\nCSS RULES:");
    const styleSheets = document.styleSheets;
    for (let i = 0; i < styleSheets.length; i++) {
        try {
            const rules = styleSheets[i].cssRules;
            for (let j = 0; j < rules.length; j++) {
                const rule = rules[j];
                // Only print rules related to vertical text or padding
                if (rule.cssText.includes('vertical') || 
                    rule.cssText.includes('padding') || 
                    rule.cssText.includes('margin') ||
                    rule.cssText.includes('body.vertical-text')) {
                    console.log(rule.cssText);
                }
            }
        } catch (e) {
            console.log("Couldn't access rules in stylesheet", i);
        }
    }
}
