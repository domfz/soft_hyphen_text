library soft_hyphen_text;

import 'package:flutter/material.dart';

class SoftHyphenText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int? maxLines;
  final double textScaleFactor;

  // The soft hyphen character (U+00AD)
  static const String softHyphen = '\u00AD';
  // Visible hyphen that will be shown when text wraps
  static const String visibleHyphen = '-';

  const SoftHyphenText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textScaleFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return _SoftHyphenTextPainter(
          text: text,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
          textScaleFactor: textScaleFactor,
          maxWidth: constraints.maxWidth,
        );
      },
    );
  }
}

class _SoftHyphenTextPainter extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int? maxLines;
  final double textScaleFactor;
  final double maxWidth;

  const _SoftHyphenTextPainter({
    required this.text,
    this.style,
    required this.textAlign,
    required this.overflow,
    this.maxLines,
    required this.textScaleFactor,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = style ?? defaultStyle;

    // Process the text to handle soft hyphens
    final processedText = _processTextWithSoftHyphens();

    return Text(
      processedText,
      style: effectiveStyle,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      textScaleFactor: textScaleFactor,
    );
  }

  String _processTextWithSoftHyphens() {
    if (!text.contains(SoftHyphenText.softHyphen)) {
      return text;
    }

    // Create a map of positions to track where soft hyphens are in the original text
    final Map<int, bool> softHyphenMap = {};

    // Build the plain text (without soft hyphens) and track hyphen positions
    final StringBuffer plainTextBuffer = StringBuffer();
    int plainTextPos = 0;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == SoftHyphenText.softHyphen) {
        softHyphenMap[plainTextPos] = true;
      } else {
        plainTextBuffer.write(text[i]);
        plainTextPos++;
      }
    }

    final String plainText = plainTextBuffer.toString();

    // Check if the text fits without wrapping
    final textPainter = TextPainter(
      text: TextSpan(text: plainText, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
    );

    textPainter.layout(maxWidth: maxWidth);

    if (textPainter.height <= textPainter.preferredLineHeight) {
      return plainText; // No need for hyphenation
    }

    // Now we need to determine where the text will wrap and insert hyphens
    // at appropriate soft hyphen positions
    return _findOptimalLineBreaks(plainText, softHyphenMap);
  }

  String _findOptimalLineBreaks(String plainText, Map<int, bool> softHyphenMap) {
    final result = StringBuffer();
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1, // Important: we want to measure one line at a time
    );

    int startPos = 0;

    while (startPos < plainText.length) {
      // First, check if all remaining text fits on one line
      textPainter.text = TextSpan(
        text: plainText.substring(startPos),
        style: style,
      );
      textPainter.layout(maxWidth: maxWidth);

      if (!textPainter.didExceedMaxLines && textPainter.width <= maxWidth) {
        // All remaining text fits, no need to wrap
        result.write(plainText.substring(startPos));
        break;
      }

      // Find the maximum amount of text that fits on one line
      int endPos = _findMaxFittingPosition(plainText, startPos, textPainter);

      // If we couldn't fit even one character, force at least one character
      if (endPos <= startPos) {
        endPos = startPos + 1;
      }

      // Try to find a space or word boundary before the break point
      int spacePos = _findLastSpaceBefore(plainText, endPos);

      // Check if we're in the middle of a word and need to use a soft hyphen
      if (spacePos <= startPos) {
        // No space was found or it's before our current position
        // Check if we can fit the entire word up to the next space
        int nextSpace = _findNextSpaceBefore(plainText, startPos, plainText.length);
        bool wordFits = false;

        if (nextSpace > startPos) {
          // Try to fit the whole word
          textPainter.text = TextSpan(
            text: plainText.substring(startPos, nextSpace),
            style: style,
          );
          textPainter.layout(maxWidth: maxWidth);
          wordFits = !textPainter.didExceedMaxLines && textPainter.width <= maxWidth;
        }

        if (!wordFits) {
          // Word doesn't fit, check for soft hyphen
          int hyphenPos = _findLastSoftHyphenBefore(endPos, softHyphenMap);

          if (hyphenPos > startPos) {
            // We found a soft hyphen position to break at
            result.write(plainText.substring(startPos, hyphenPos));
            result.write(SoftHyphenText.visibleHyphen);
            startPos = hyphenPos;
          } else {
            // No soft hyphen found, just break at the max fitting position
            result.write(plainText.substring(startPos, endPos));
            startPos = endPos;
          }
        } else {
          // Word fits entirely, include it
          result.write(plainText.substring(startPos, nextSpace));
          startPos = nextSpace;
        }
      } else {
        // We found a space
        // Check if the text after the space through the next space also fits
        int nextSpace = _findNextSpaceBefore(plainText, spacePos + 1, plainText.length);
        bool nextWordFits = false;

        if (nextSpace > spacePos + 1) {
          textPainter.text = TextSpan(
            text: plainText.substring(startPos, nextSpace),
            style: style,
          );
          textPainter.layout(maxWidth: maxWidth);
          nextWordFits = !textPainter.didExceedMaxLines && textPainter.width <= maxWidth;
        }

        if (nextWordFits) {
          // Next word also fits, include it
          result.write(plainText.substring(startPos, nextSpace));
          startPos = nextSpace;
        } else {
          // Break at space
          result.write(plainText.substring(startPos, spacePos));
          startPos = spacePos + 1; // Skip the space on the next line
        }
      }

      // Add a newline if we're not at the end
      if (startPos < plainText.length) {
        result.write('\n');
      }
    }

    return result.toString();
  }

  int _findMaxFittingPosition(String text, int startPos, TextPainter textPainter) {
    int low = startPos;
    int high = text.length;

    while (low < high) {
      int mid = (low + high + 1) ~/ 2;

      textPainter.text = TextSpan(
        text: text.substring(startPos, mid),
        style: style,
      );

      textPainter.layout(maxWidth: maxWidth);

      if (textPainter.didExceedMaxLines || textPainter.width > maxWidth) {
        high = mid - 1;
      } else {
        low = mid;
      }
    }

    return low;
  }

  int _findLastSpaceBefore(String text, int position) {
    for (int i = position - 1; i >= 0; i--) {
      if (text[i] == ' ') {
        return i;
      }
    }
    return -1;
  }

  int _findLastSoftHyphenBefore(int position, Map<int, bool> softHyphenMap) {
    for (int i = position - 1; i >= 0; i--) {
      if (softHyphenMap.containsKey(i) && softHyphenMap[i]!) {
        return i;
      }
    }
    return -1;
  }

  int _findNextSpaceBefore(String text, int startPos, int maxPos) {
    for (int i = startPos; i < maxPos; i++) {
      if (text[i] == ' ') {
        return i;
      }
    }
    return maxPos;
  }
}
