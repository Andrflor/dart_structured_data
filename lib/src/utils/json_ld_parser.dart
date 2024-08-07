import 'dart:convert';

import 'package:html/dom.dart';
import 'package:structured_data/src/utils/parser_helper.dart';

import '../objects/structured_data.dart';
import 'html_parser.dart';

final singleCommentRegex = RegExp(r'((?<=[^:])|^)\/\/.*\n');
final multiCommentRegex = RegExp(r'/\*.*?\*/', dotAll: true);
final doubleEscapedChar = RegExp(r'\\[^\\"bfnrtu]');
final bracketOpenRegex = RegExp(r'\{');
final bracketCloseRegex = RegExp(r'\}');
final listOpenRegex = RegExp(r'\[');
final listCloseRegex = RegExp(r'\]');
final trailingCommaRegex = RegExp(r',\s*([\}\]])');
final jsonStartRegex = RegExp(r'[\[\{]');
final jsonEndRegex = RegExp(r'[\]\}]');
final breakingLineString = RegExp(r'[^"]*(?:""[^"]*)*');

class JsonLdParser {
  static List<StructuredData> extractJsonLd(Document document) {
    var scopes = HtmlQuery.findJsonLds(document);
    List<StructuredData> items = [];
    scopes.forEach((itemscope) {
      try {
        var data = jsonDecode(cleanJsonString(itemscope.text));
        if (data is List) {
          items.addAll(_extractDataFromList(data));
        } else {
          List<StructuredData> schemas = _extractDataFromObject(data);
          items.addAll(schemas);
        }
      } catch (_) {}
    });

    return items;
  }

  static String cleanJsonString(String input) {
    String sanitized = input
        .replaceAll(singleCommentRegex, '')
        .replaceAll(multiCommentRegex, '')
        .replaceAllMapped(
            breakingLineString,
            (m) =>
                '${m.group(0)!.replaceAll("\n", "").replaceAll("\t", "").replaceAll("\b", "")}')
        .replaceAllMapped(
            doubleEscapedChar, (match) => match.group(0)!.substring(1));

    int startIndex = sanitized.indexOf(jsonStartRegex);
    int endIndex = sanitized.lastIndexOf(jsonEndRegex);
    if (startIndex == -1 || endIndex == -1) {
      throw FormatException(
          "Invalid JSON: Missing opening or closing brackets");
    }
    sanitized = sanitized.substring(startIndex, endIndex + 1);

    sanitized = sanitized.replaceAllMapped(
        trailingCommaRegex, (match) => match.group(1)!);

    int openingCurlyBrackets = bracketOpenRegex.allMatches(sanitized).length;
    int closingCurlyBrackets = bracketCloseRegex.allMatches(sanitized).length;
    int openingSquareBrackets = listOpenRegex.allMatches(sanitized).length;
    int closingSquareBrackets = listCloseRegex.allMatches(sanitized).length;

    if (openingCurlyBrackets > closingCurlyBrackets) {
      sanitized += '}' * (openingCurlyBrackets - closingCurlyBrackets);
    }
    if (closingCurlyBrackets > openingCurlyBrackets) {
      sanitized =
          '{' * (closingCurlyBrackets - openingCurlyBrackets) + sanitized;
    }
    if (openingSquareBrackets > closingSquareBrackets) {
      sanitized += ']' * (openingSquareBrackets - closingSquareBrackets);
    }
    if (closingSquareBrackets > openingSquareBrackets) {
      sanitized =
          '[' * (closingSquareBrackets - openingSquareBrackets) + sanitized;
    }

    return sanitized;
  }

  static List<StructuredData> _extractDataFromObject(
      Map<String, dynamic> data) {
    final List<StructuredData> results = [];
    if (data.containsKey('@graph')) {
      results.addAll(_extractDataFromList(data['@graph']));
    }
    if (data.containsKey('@type')) {
      results.add(_extractStructuredData(data));
    }
    return results;
  }

  static List<StructuredData> _extractDataFromList(List data) {
    final List<StructuredData> items = [];
    data.forEach((element) {
      StructuredData schema = _extractStructuredData(element);
      items.add(schema);
    });
    return items;
  }

  static StructuredData _extractStructuredData(Map<String, dynamic> jsonObj) {
    StructuredData schema =
        StructuredData(ParserHelper.stripProperty(jsonObj["@type"]) ?? "");
    jsonObj.keys.forEach((property) {
      if (!_shouldIgnoreProp(property)) {
        var propertyData = jsonObj[property];

        // If it's a map, then parse it as a structured data object
        if (propertyData is Map<String, dynamic>) {
          StructuredData structuredProperty =
              _extractStructuredData(propertyData);
          schema.addData(property, structuredProperty);
        } else if (propertyData is String) {
          // For a string, strip out any extra data
          schema.addData(property, ParserHelper.stripProperty(propertyData));
        } else if (propertyData is List) {
          // For a list, check the data type first before deciding what to do
          if (propertyData.length > 0) {
            if (propertyData[0] is Map) {
              // For a map, parse all of these into structured datas
              final List<StructuredData> dataList = [];
              propertyData.forEach((element) {
                var parsedResult = _extractStructuredData(element);
                dataList.add(parsedResult);
              });
              schema.addData(property, dataList);
            } else {
              // For other types, simply add to the data list
              schema.addData(property, propertyData);
            }
          }
        } else {
          schema.addData(property, propertyData);
        }
      }
    });

    return schema;
  }

  static bool _shouldIgnoreProp(String prop) {
    if (prop.startsWith('@')) {
      return true;
    }
    switch (prop) {
      case "@context":
      case "@type":
        return true;
      default:
        return false;
    }
  }
}
