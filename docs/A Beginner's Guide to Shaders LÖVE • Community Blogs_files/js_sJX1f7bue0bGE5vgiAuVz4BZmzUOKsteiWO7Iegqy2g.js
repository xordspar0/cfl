
/**
 * @file
 * SyntaxHighlighter JavaScript.
 *
 * @author: Matthew Young <www.hddigitalworks.com/contact>
 * @author: Tom Kirkpatrick (mrfelton), www.kirkdesigns.co.uk
 */

 
  // Initialize settings.
Drupal.settings.syntaxhighlighter = jQuery.extend({
  tagName:       false,
  clipboard:     true,
  legacyMode:    false,
  useAutoloader: false
}, Drupal.settings.syntaxhighlighter || {});
  
SyntaxHighlighter.config.strings.expandSource = Drupal.t('expand source');
SyntaxHighlighter.config.strings.viewSource = Drupal.t('view source');
SyntaxHighlighter.config.strings.copyToClipboard = Drupal.t('copy to clipboard');
SyntaxHighlighter.config.strings.copyToClipboardConfirmation = Drupal.t('The code is in your clipboard now');
SyntaxHighlighter.config.strings.print = Drupal.t('print');
SyntaxHighlighter.config.strings.help = Drupal.t('?');

SyntaxHighlighter.defaults.toolbar = false;

SyntaxHighlighter.config.strings.alert = Drupal.t('SyntaxHighlighter\n\n');
SyntaxHighlighter.config.strings.noBrush = Drupal.t('Can\'t find brush for: ');
SyntaxHighlighter.config.strings.brushNotHtmlScript = Drupal.t('Brush wasn\'t made for html-script option: ');

if (Drupal.settings.syntaxhighlighter.tagName) {
  SyntaxHighlighter.config.tagName = Drupal.settings.syntaxhighlighter.tagName;
}


if (SyntaxHighlighter.config.clipboardSwf !== undefined && SyntaxHighlighter.config.clipboardSwf === null && Drupal.settings.syntaxhighlighter.clipboard) {
  SyntaxHighlighter.config.clipboardSwf = Drupal.settings.syntaxhighlighter.clipboard;
}


jQuery(function($) {
  if (Drupal.settings.syntaxhighlighter.useAutoloader) {
    syntaxhighlighterAutoloaderSetup();
    SyntaxHighlighter.all();
  } else {
    SyntaxHighlighter.highlight();
  }
  if (Drupal.settings.syntaxhighlighter.legacyMode) {
    dp.SyntaxHighlighter.HighlightAll('code');
  }
  
  Drupal.behaviors.syntaxhighlighter = {
    attach: function(context, settings) {
      if (context) {
	    var elements = $(SyntaxHighlighter.config.tagName, context).get();
	    var length = elements.length
	    for (i = 0 ; i < length ; ++i) {
          SyntaxHighlighter.highlight(SyntaxHighlighter.defaults, elements[i]);
	    }
	  } else {
        SyntaxHighlighter.highlight();
	  }
      if (settings.syntaxhighlighter.legacyMode) {
        dp.SyntaxHighlighter.HighlightAll('code');
      }
    }
  }
});
;
