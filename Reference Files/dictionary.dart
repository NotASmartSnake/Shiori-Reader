// This file contains all the files for the dictionary functionality from the 
// "immersion_reader" github repo that I'm using as inspiration for the dictionary
// functionality for my own app. Please use this as a reference when determing
// functionality for dictionaries for my own app.

// dictionary_entry.dart
// https://github.com/lrorpilla/jidoujisho/blob/1ef19254b67fb766fa49fa12a82b009f31ec5419/chisa/lib/dictionary/dictionary_entry.dart

class DictionaryEntry {
  /// Initialise a dictionary entry with given details of a certain term.
  DictionaryEntry(
      {required this.term,
      required this.meanings,
      this.reading = '',
      this.id,
      this.dictionaryId,
      this.extra,
      this.meaningTags = const [],
      this.termTags = const [],
      this.popularity,
      this.sequence,
      this.index,
      this.transformedText});

  factory DictionaryEntry.fromMap(Map<String, Object?> map) => DictionaryEntry(
      id: map['id'] as int?,
      dictionaryId: map['dictionaryId'] as int,
      meanings:
          map['meanings'] != null ? (map['glossary'] as String).split(';') : [],
      term: map['expression'] as String,
      reading: map['reading'] as String,
      popularity: map['popularity'] as double,
      sequence: map['sequence'] as int,
      meaningTags: (map['meaningTags'] as String).split(' '),
      termTags: (map['termTags'] as String).split(' '));

  /// A unique identifier for the purposes of database storage.
  int? id;

  // for batch search
  int? index;

  // for highlighting the original word
  String? transformedText;

  /// The term represented by this dictionary entry.
  final String term;

  int? dictionaryId;

  /// The pronunciation of the term represented by this dictionary entry.
  final String reading;

  /// A list of definitions for a term. If there is only a single [String] item,
  /// this should be a single item list.
  List<String> meanings;

  /// A bonus field for storing any additional kind of information. For example,
  /// if there are any grammar rules related to this term.
  final String? extra;

  /// Tags that are used to indicate a certain trait to the definitions of
  /// this term.
  final List<String> meaningTags;

  /// Tags that are used to indicate a certain trait to this particular term.
  final List<String> termTags;

  /// A value that can be used to sort entries when performing a database
  /// search.
  final double? popularity;

  /// A value that can be used to group similar entries with the same value
  /// together.
  final int? sequence;

  /// The length of term is used as an index.
  int get termLength => term.length;

  /// The length of reading is used as an index.
  int get readingLength => reading.length;

  @override
  operator ==(Object other) => other is DictionaryEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// dictionary_meta_entry.dart

import './pitch_data.dart';

class DictionaryMetaEntry {
  /// Initialise a dictionary entry with given details of a certain word.
  DictionaryMetaEntry({
    required this.dictionaryName,
    required this.term,
    this.reading,
    this.pitches,
    this.frequency,
    this.id,
  });

  /// A unique identifier for the purposes of database storage.
  int? id;

  /// The word or phrase represented by this dictionary entry.
  final String term;

  // Reading for the frequency
  final String? reading;

  /// Length of the term.
  int get termLength => term.length;

  /// The dictionary from which this entry was imported from. This is used for
  /// database query purposes.
  final String dictionaryName;

  /// The frequency of this term.
  final String? frequency;

  /// List of pitch accent downsteps for this term's reading.
  final List<PitchData>? pitches;

  @override
  operator ==(Object other) => other is DictionaryMetaEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// dictionary_options.dart 

enum PitchAccentDisplayStyle { none, graph, number }

enum PopupDictionaryTheme { dark, dracula, light, purple }

class DictionaryOptions {
  List<int> disabledDictionaryIds;
  bool isGetFrequencyTags;
  PitchAccentDisplayStyle pitchAccentDisplayStyle;
  PopupDictionaryTheme popupDictionaryTheme;

  bool sorted;

  DictionaryOptions(
      {this.disabledDictionaryIds = const [],
      this.isGetFrequencyTags = true,
      this.pitchAccentDisplayStyle = PitchAccentDisplayStyle.graph,
      this.popupDictionaryTheme = PopupDictionaryTheme.dark,
      this.sorted = true});
}

// dictionary_parser.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:immersion_reader/widgets/settings/dictionary_settings.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:immersion_reader/utils/folder_utils.dart';
import './user_dictionary.dart';
import './dictionary_entry.dart';
import './dictionary_meta_entry.dart';
import './pitch_data.dart';

// https://github.com/lrorpilla/jidoujisho/blob/e445b09ea8fa5df2bfae8a0d405aa1ba5fc32767/yuuna/lib/src/dictionary/formats/yomichan_dictionary_format.dart
Future<UserDictionary> parseDictionary(
    {required File zipFile,
    StreamController<(DictionaryImportStage, double)>?
        progressController}) async {
  Directory workingDirectory = await FolderUtils.getWorkingFolder();
  try {
    await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: workingDirectory,
        onExtracting: (zipEntry, progress) {
          progressController?.add((DictionaryImportStage.extracting, progress));
          return ZipFileOperation.includeItem;
        });
    progressController?.add((DictionaryImportStage.parsing, -1));
    final List<FileSystemEntity> entities = workingDirectory.listSync();
    final Iterable<File> files = entities.whereType<File>();

    List<File> termFiles = List.from(
        files.where((file) => p.basename(file.path).startsWith('term_bank')));
    List<File> metaFiles = List.from(files
        .where((file) => p.basename(file.path).startsWith('term_meta_bank')));
    // List<File> tagFiles = List.from(
    //     files.where((file) => p.basename(file.path).startsWith('tag_bank')));

    String dictionaryName = getDictionaryName(workingDirectory);

    List<DictionaryEntry> dictionaryEntries =
        parseTerms(termFiles, dictionaryName);
    List<DictionaryMetaEntry> dictionaryMetaEntries =
        parseMetaTerms(metaFiles, dictionaryName);
    // List<DictionaryTag> dictionaryTags = parseTags(tagFiles, dictionaryName);
    return UserDictionary(
        dictionaryName: dictionaryName,
        dictionaryEntries: dictionaryEntries,
        dictionaryMetaEntries: dictionaryMetaEntries,
        dictionaryTags: []);
  } catch (e) {
    debugPrint(e.toString());
  }
  throw Exception('Unable to produce dictionary');
}

// List<DictionaryTag> parseTags(List<File> files, String dictionaryName) {
//   List<DictionaryTag> tags = [];
//   for (File file in files) {
//     List<dynamic> items = jsonDecode(file.readAsStringSync());
//     for (List<dynamic> item in items) {
//       String name = item[0] as String;
//       String category = item[1] as String;
//       int sortingOrder = item[2] as int;
//       String notes = item[3] as String;
//       double popularity = (item[4] as num).toDouble();

//       DictionaryTag tag = DictionaryTag(
//         dictionaryName: dictionaryName,
//         name: name,
//         category: category,
//         sortingOrder: sortingOrder,
//         notes: notes,
//         popularity: popularity,
//       );

//       tags.add(tag);
//     }
//   }
//   return tags;
// }

List<DictionaryEntry> parseTerms(List<File> files, String dictionaryName) {
  List<DictionaryEntry> entries = [];
  for (File file in files) {
    List<dynamic> items = jsonDecode(file.readAsStringSync());

    for (List<dynamic> item in items) {
      String term = item[0] as String;
      String reading = item[1] as String;

      double popularity = (item[4] as num).toDouble();
      List<String> meaningTags = (item[2] as String).split(' ');
      List<String> termTags = (item[7] as String).split(' ');

      List<String> meanings = [];
      int? sequence = item[6] as int?;

      if (item[5] is List) {
        List<dynamic> meaningsList = List.from(item[5]);
        meanings = meaningsList.map((e) => e.toString()).toList();
      } else {
        meanings.add(item[5].toString());
      }
      entries.add(
        DictionaryEntry(
          term: term,
          reading: reading,
          meanings: meanings,
          popularity: popularity,
          meaningTags: meaningTags,
          termTags: termTags,
          sequence: sequence,
        ),
      );
    }
  }
  return entries;
}

List<DictionaryMetaEntry> parseMetaTerms(
    List<File> files, String dictionaryName) {
  List<DictionaryMetaEntry> metaEntries = [];
  for (File file in files) {
    String json = file.readAsStringSync();
    List<dynamic> items = jsonDecode(json);

    for (List<dynamic> item in items) {
      String term = item[0] as String;
      String type = item[1] as String;
      String reading = '';

      String? frequency;
      List<PitchData>? pitches;

      if (type == 'pitch') {
        pitches = [];

        Map<String, dynamic> data = Map<String, dynamic>.from(item[2]);
        String reading = data['reading'];

        List<Map<String, dynamic>> distinctPitchJsons =
            List<Map<String, dynamic>>.from(data['pitches']);
        for (Map<String, dynamic> distinctPitch in distinctPitchJsons) {
          int downstep = distinctPitch['position'];
          PitchData pitch = PitchData(
            reading: reading,
            downstep: downstep,
          );
          pitches.add(pitch);
        }
      } else if (type == 'freq') {
        if (item[2] is double) {
          double number = item[2] as double;
          if (number % 1 == 0) {
            frequency = '${number.toInt()}';
          } else {
            frequency = '$number';
          }
        } else if (item[2] is int) {
          int number = item[2] as int;
          frequency = '$number';
        } else if (item[2] is Object) {
          if (item[2]['frequency'] != null) {
            int number = item[2]['frequency'] as int;
            frequency = '$number';
            // print(frequency);
          }
          if (item[2]['reading'] != null) {
            reading = item[2]['reading'];
            // print(reading);
          }
        } else {
          frequency = item[2].toString();
        }
      } else {
        continue;
      }

      DictionaryMetaEntry metaEntry = DictionaryMetaEntry(
        dictionaryName: dictionaryName,
        term: term,
        reading: reading,
        frequency: frequency,
        pitches: pitches,
      );

      metaEntries.add(metaEntry);
    }
  }
  return metaEntries;
}

String getDictionaryName(Directory workingDirectory) {
  try {
    /// Get the index, which contains the name of the dictionary contained by
    /// the archive.
    String indexFilePath = p.join(workingDirectory.path, 'index.json');
    File indexFile = File(indexFilePath);
    String indexJson = indexFile.readAsStringSync();
    Map<String, dynamic> index = jsonDecode(indexJson);

    String dictionaryName = (index['title'] as String).trim();
    return dictionaryName;
  } catch (e) {
    debugPrint(e.toString());
  }
  throw Exception('Unable to get name');
}

// dictionary_tag.dart 

import 'package:flutter/cupertino.dart';

/// A helper class for tags that are present in Yomichan imported dictionary
/// entries.
class DictionaryTag {
  /// Define a tag with given parameters.
  DictionaryTag({
    required this.dictionaryName,
    required this.name,
    required this.category,
    required this.sortingOrder,
    required this.notes,
    required this.popularity,
    this.id,
  });

  /// The dictionary from which this entry was imported from. This is used for
  /// database query purposes.
  final String dictionaryName;

  /// Tag name.
  final String name;

  /// Category for the tag.
  final String category;

  /// Sorting order for the tag.
  final int sortingOrder;

  /// Notes for this tag.
  final String notes;

  /// Score used to determine popularity.
  /// Negative values are more rare and positive values are more frequent.
  /// This score is also used to sort search results.
  final double? popularity;

  /// The length of word is used as an index.
  String get uniqueKey => '$dictionaryName/$name';

  /// A unique identifier for the purposes of database storage.
  int? id;

  /// Get the color for this tag based on its category.
  Color get color {
    switch (category) {
      case 'name':
        return const Color(0xffd46a6a);
      case 'expression':
        return const Color(0xffff4d4d);
      case 'popular':
        return const Color(0xff550000);
      case 'partOfSpeech':
        return const Color(0xff565656);
      case 'archaism':
        return const Color(0xff616161);
      case 'dictionary':
        return const Color(0xffa15151);
      case 'frequency':
        return const Color(0xffd46a6a);
      case 'frequent':
        return const Color(0xff801515);
    }

    return const Color(0xff616161);
  }
}

// frequency_tag.dart

class FrequencyTag {
  FrequencyTag(
      {required this.dictionaryId,
      required this.frequency,
      this.dictionaryName});

  int dictionaryId;
  String frequency;
  String? dictionaryName;

  factory FrequencyTag.fromMap(Map<String, Object?> map) => FrequencyTag(
      dictionaryId: map['dictionaryId'] as int,
      frequency: map['frequency'] as String);
}

// pitch_data.dart

class PitchData {
  /// Initialise a dictionary entry with given details of a certain word.
  PitchData({
    required this.reading,
    required this.downstep,
  });

  /// The pronunciation of the word represented by this dictionary entry.
  final String reading;

  /// The downstep for this term's reading.
  final int downstep;
}

// user_dictionary.dart

import './dictionary_entry.dart';
import './dictionary_meta_entry.dart';
import './dictionary_tag.dart';

class UserDictionary {
  String dictionaryName;
  List<DictionaryEntry> dictionaryEntries;
  List<DictionaryMetaEntry> dictionaryMetaEntries;
  List<DictionaryTag> dictionaryTags;

  UserDictionary(
      {required this.dictionaryName,
      required this.dictionaryEntries,
      required this.dictionaryMetaEntries,
      required this.dictionaryTags});
}

