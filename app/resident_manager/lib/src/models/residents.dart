import "dart:convert";

import "info.dart";
import "results.dart";
import "snowflake.dart";
import "../state.dart";

/// Represents a resident.
class Resident extends PublicInfo {
  /// Constructs a [Resident] object with the given [id], [name], [room], [birthday], [phone], and [email].
  Resident({
    required super.id,
    required super.name,
    required super.room,
    super.birthday,
    super.phone,
    super.email,
    super.username,
    super.hashedPassword,
  });

  Resident.fromJson(super.data) : super.fromJson();

  @override
  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "room": room,
        "birthday": birthday?.toIso8601String(),
        "phone": phone,
        "email": email,
      };

  Future<Result<Resident?>> update({
    required ApplicationState state,
    required PersonalInfo info,
  }) async {
    final headers = {"content-type": "application/json"};
    final response = await state.post(
      state.loggedInAsAdmin ? "/api/v1/admin/residents/update" : "/api/v1/residents/update",
      queryParameters: {"id": id.toString()},
      headers: headers,
      body: json.encode(info.toJson()),
    );
    final result = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return Result(0, Resident.fromJson(result["data"]));
    }

    return Result(result["code"], null);
  }

  static Future<bool> delete({
    required ApplicationState state,
    required Iterable<Snowflake> objects,
  }) async {
    final headers = {"content-type": "application/json"};
    final data = List<Map<String, int>>.from(objects.map((o) => {"id": o.id}));

    final response = await state.post("/api/v1/admin/residents/delete", headers: headers, body: json.encode(data));
    return response.statusCode == 204;
  }

  static Future<Result<List<Resident>?>> query({
    required ApplicationState state,
    required int offset,
    int? id,
    String? name,
    int? room,
    String? username,
    String? orderBy,
    bool? ascending,
  }) async {
    if (!state.loggedInAsAdmin) {
      return Result(-1, null);
    }

    final response = await state.get(
      "/api/v1/admin/residents",
      queryParameters: {
        "offset": offset.toString(),
        if (id != null) "id": id.toString(),
        if (name != null && name.isNotEmpty) "name": name,
        if (room != null) "room": room.toString(),
        if (username != null && username.isNotEmpty) "username": username,
        if (orderBy != null && orderBy.isNotEmpty) "order_by": orderBy,
        if (ascending != null) "ascending": ascending.toString(),
      },
    );
    final result = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      final data = result["data"] as List<dynamic>;
      return Result(0, List<Resident>.from(data.map(Resident.fromJson)));
    }

    return Result(result["code"], null);
  }

  /// Count the number of residents.
  static Future<Result<int?>> count({
    required ApplicationState state,
    int? id,
    String? name,
    int? room,
    String? username,
  }) async {
    final response = await state.get(
      "/api/v1/admin/residents/count",
      queryParameters: {
        if (id != null) "id": id.toString(),
        if (name != null && name.isNotEmpty) "name": name,
        if (room != null) "room": room.toString(),
        if (username != null && username.isNotEmpty) "username": username,
      },
    );
    final result = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return Result(0, result["data"]);
    }

    return Result(result["code"], null);
  }
}
