/// Represents a generic schema object
class StructuredData {
  StructuredData(this.name);

  final String name;
  Map<String, dynamic> _data = Map<String, dynamic>();

  dynamic operator [](String key) => _data[key];

  /// Adds property data to the data map
  /// Handles creating a list out of duplicate properties
  addData(String propertyName, dynamic propertyData) {
    // If the property is being added multiple times, then it becomes
    // a list attribute.
    var cleanData = _cleanData(propertyData);
    if (_data.containsKey(propertyName)) {
      _convertPropertyToList(propertyName);
      // Now that the property is a list, add the 2nd property
      _data[propertyName].add(cleanData);
    } else {
      // Otherwise this is the first time the property is being added.
      // just add it to the list.
      _data[propertyName] = cleanData;
    }
  }

  _convertPropertyToList(String property) {
    var is_list = _data[property] is List;

    if (!is_list) {
      var tmp = _data[property];
      _data[property] = List<dynamic>();
      _data[property].add(tmp);
    }
  }

  dynamic _cleanData(dynamic property) {
    if (property is String) {
      return property.trim();
    } else {
      return property;
    }
  }
}