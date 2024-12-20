import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:async_locks/async_locks.dart";
import "package:flutter/material.dart";
import "package:flutter_localization/flutter_localization.dart";

import "../common.dart";
import "../state.dart";
import "../utils.dart";
import "../../config.dart";
import "../../translations.dart";
import "../../utils.dart";
import "../../models/info.dart";
import "../../models/residents.dart";
import "../../models/rooms.dart";

class ResidentsPage extends StateAwareWidget {
  const ResidentsPage({super.key, required super.state});

  @override
  AbstractCommonState<ResidentsPage> createState() => _ResidentsPageState();
}

class _Pagination extends FutureHolder<int?> {
  int offset = 0;
  int offsetLimit = 0;

  final _ResidentsPageState _state;

  _Pagination(this._state);

  @override
  Future<int?> run() async {
    try {
      final result = await Resident.count(
        state: _state.state,
        name: _state.name,
        room: int.tryParse(_state.room ?? ""),
        username: _state.username,
      );

      final data = result.data;
      if (data != null) {
        offsetLimit = (data + DB_PAGINATION_QUERY - 1) ~/ DB_PAGINATION_QUERY - 1;
      } else {
        offsetLimit = offset;
      }

      return result.code;
    } catch (e) {
      offsetLimit = offset;
      if (e is SocketException || e is TimeoutException) {
        await showToastSafe(msg: _state.mounted ? AppLocale.ConnectionError.getString(_state.context) : AppLocale.ConnectionError);
        return null;
      }

      rethrow;
    } finally {
      _state.refresh();
    }
  }
}

class _QueryLoader extends FutureHolder<int?> {
  final residents = <Resident>[];
  final selected = SplayTreeSet<Resident>((k1, k2) => k1.id.compareTo(k2.id));

  String orderBy = "id";
  bool ascending = false;

  final _ResidentsPageState _state;

  _QueryLoader(this._state);

  @override
  Future<int?> run() async {
    try {
      final result = await Resident.query(
        state: _state.state,
        offset: DB_PAGINATION_QUERY * _state.pagination.offset,
        name: _state.name,
        room: int.tryParse(_state.room ?? ""),
        username: _state.username,
        orderBy: orderBy,
        ascending: ascending,
      );

      final data = result.data;
      if (data != null) {
        residents.clear();
        residents.addAll(data);
        residents.removeWhere(selected.contains);
        residents.addAll(selected);
      }

      return result.code;
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        await showToastSafe(msg: _state.mounted ? AppLocale.ConnectionError.getString(_state.context) : AppLocale.ConnectionError);
        return null;
      }

      rethrow;
    } finally {
      _state.refresh();
    }
  }
}

class _EditButton extends StatelessWidget {
  final Resident resident;
  final _ResidentsPageState state;

  const _EditButton(this.resident, this.state);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.edit_outlined),
      onPressed: () async {
        final nameController = TextEditingController(text: resident.name);
        final roomController = TextEditingController(text: resident.room.toString());
        final birthdayController = TextEditingController(text: resident.birthday?.format("dd/mm/yyyy"));
        final phoneController = TextEditingController(text: resident.phone);
        final emailController = TextEditingController(text: resident.email);

        final formKey = GlobalKey<FormState>();
        final submitted = await showDialog<bool>(
          context: context,
          builder: (context) => SimpleDialog(
            contentPadding: const EdgeInsets.all(10),
            title: Text(AppLocale.EditPersonalInfo.getString(context)),
            children: [
              Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        label: FieldLabel(
                          AppLocale.Fullname.getString(context),
                          style: const TextStyle(color: Colors.black),
                          required: true,
                        ),
                      ),
                      validator: (value) => nameValidator(context, required: true, value: value),
                    ),
                    TextFormField(
                      controller: roomController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        label: FieldLabel(
                          AppLocale.Room.getString(context),
                          style: const TextStyle(color: Colors.black),
                          required: true,
                        ),
                      ),
                      validator: (value) => roomValidator(context, required: true, value: value),
                    ),
                    TextFormField(
                      controller: birthdayController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        label: FieldLabel(
                          AppLocale.DateOfBirth.getString(context),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      onTap: () async {
                        final birthday = await showDatePicker(
                          context: context,
                          initialDate: Date.parseFriendly(birthdayController.text)?.toDateTime(),
                          firstDate: DateTime.utc(1900),
                          lastDate: DateTime.now(),
                        );

                        if (birthday != null) {
                          birthdayController.text = Date.fromDateTime(birthday).format("dd/mm/yyyy");
                        } else {
                          birthdayController.clear();
                        }
                      },
                      readOnly: true, // no need for validator
                    ),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        label: FieldLabel(
                          AppLocale.Phone.getString(context),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      validator: (value) => phoneValidator(context, value: value),
                    ),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8.0),
                        label: FieldLabel(
                          AppLocale.Email.getString(context),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      validator: (value) => emailValidator(context, value: value),
                    ),
                    const SizedBox.square(dimension: 10),
                    Container(
                      padding: const EdgeInsets.all(5),
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.done_outlined),
                        label: Text(AppLocale.Confirm.getString(context)),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (submitted != null) {
          final check = formKey.currentState?.validate() ?? false;
          if (check) {
            await state._actionLock.run(
              () async {
                state._notification = Builder(
                  builder: (context) => Text(
                    AppLocale.Loading.getString(context),
                    style: const TextStyle(color: Colors.blue),
                  ),
                );
                state.refresh();

                try {
                  final result = await resident.update(
                    state: state.state,
                    info: PersonalInfo(
                      name: nameController.text,
                      room: int.parse(roomController.text),
                      birthday: birthdayController.text.isEmpty ? null : Date.parseFriendly(birthdayController.text),
                      phone: phoneController.text,
                      email: emailController.text,
                    ),
                  );

                  if (result.code != 0) {
                    state._notification = Builder(
                      builder: (context) => Text(
                        AppLocale.errorMessage(result.code).getString(context),
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else {
                    state._notification = const SizedBox.shrink();
                  }
                } catch (e) {
                  await showToastSafe(msg: context.mounted ? AppLocale.ConnectionError.getString(context) : AppLocale.ConnectionError);
                  state._notification = Builder(
                    builder: (context) => Text(
                      AppLocale.ConnectionError.getString(context),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );

                  if (!(e is SocketException || e is TimeoutException)) {
                    rethrow;
                  }
                } finally {
                  state.reload();
                }
              },
            );
          }
        }
      },
    );
  }
}

class _ResidentsPageState extends AbstractCommonState<ResidentsPage> with CommonScaffoldStateMixin<ResidentsPage> {
  String? name;
  String? room;
  String? username;

  bool get searching => name != null || room != null || username != null;

  _Pagination? _pagination;
  _Pagination get pagination => _pagination ??= _Pagination(this);

  _QueryLoader? _queryLoader;
  _QueryLoader get queryLoader => _queryLoader ??= _QueryLoader(this);

  Widget _notification = const SizedBox.shrink();

  final _actionLock = Lock();

  void reload() {
    pagination.reload();
    queryLoader.reload();
    refresh();
  }

  Future<void> _deleteAccounts() async {
    await _actionLock.run(
      () async {
        _notification = Builder(
          builder: (context) => Text(
            AppLocale.Loading.getString(context),
            style: const TextStyle(color: Colors.blue),
          ),
        );
        refresh();

        try {
          if (await Resident.delete(state: state, objects: queryLoader.selected)) {
            queryLoader.selected.clear();
          }

          _notification = const SizedBox.shrink();
        } catch (e) {
          await showToastSafe(msg: mounted ? AppLocale.ConnectionError.getString(context) : AppLocale.ConnectionError);
          _notification = Builder(
            builder: (context) => Text(
              AppLocale.ConnectionError.getString(context),
              style: const TextStyle(color: Colors.red),
            ),
          );

          if (!(e is SocketException || e is TimeoutException)) {
            rethrow;
          }
        } finally {
          reload();
        }
      },
    );
  }

  @override
  void initState() {
    final room = state.extras["room-search"] as Room?;
    if (room != null) {
      this.room = room.room.toString();
      state.extras["room-search"] = null;
    }

    super.initState();
  }

  @override
  CommonScaffold<ResidentsPage> build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return CommonScaffold.single(
      widgetState: this,
      title: Text(AppLocale.ResidentsList.getString(context), style: const TextStyle(fontWeight: FontWeight.bold)),
      sliver: FutureBuilder(
        future: queryLoader.future,
        builder: (context, snapshot) {
          if (queryLoader.isLoading) {
            return const SliverCircularProgressFullScreen();
          }

          final code = snapshot.data;
          if (code == 0) {
            TableCell headerCeil(String text, [String? newOrderBy]) {
              if (newOrderBy != null) {
                if (queryLoader.orderBy == newOrderBy) {
                  text += queryLoader.ascending ? " ▴" : " ▾";
                } else {
                  text += " ▴▾";
                }
              }

              return TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: GestureDetector(
                    onTap: () {
                      if (newOrderBy != null) {
                        if (newOrderBy == queryLoader.orderBy) {
                          queryLoader.ascending = !queryLoader.ascending;
                        } else {
                          queryLoader.ascending = true;
                        }

                        queryLoader.orderBy = newOrderBy;
                        pagination.offset = 0;
                        reload();
                      }
                    },
                    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }

            final rows = [
              TableRow(
                decoration: const BoxDecoration(border: BorderDirectional(bottom: BorderSide(width: 1))),
                children: [
                  TableCell(
                    child: Checkbox.adaptive(
                      value: queryLoader.selected.containsAll(queryLoader.residents),
                      onChanged: (state) {
                        if (state != null) {
                          if (state) {
                            queryLoader.selected.addAll(queryLoader.residents);
                          } else {
                            queryLoader.selected.removeAll(queryLoader.residents);
                          }
                        }

                        refresh();
                      },
                    ),
                  ),
                  headerCeil(AppLocale.Fullname.getString(context), "name"),
                  headerCeil(AppLocale.Room.getString(context), "room"),
                  headerCeil(AppLocale.DateOfBirth.getString(context)),
                  headerCeil(AppLocale.Phone.getString(context)),
                  headerCeil(AppLocale.Email.getString(context)),
                  headerCeil(AppLocale.CreationTime.getString(context), "id"),
                  headerCeil(AppLocale.Username.getString(context), "username"),
                  headerCeil(AppLocale.Option.getString(context)),
                ],
              ),
              ...List<TableRow>.from(
                queryLoader.residents.map(
                  (resident) => TableRow(
                    children: [
                      Checkbox.adaptive(
                        value: queryLoader.selected.contains(resident),
                        onChanged: (state) {
                          if (state != null) {
                            if (state) {
                              queryLoader.selected.add(resident);
                            } else {
                              queryLoader.selected.remove(resident);
                            }
                          }

                          refresh();
                        },
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.name),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.room.toString()),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.birthday?.format("dd/mm/yyyy") ?? "---"),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.phone ?? "---"),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.email ?? "---"),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.createdAt.toLocal().toString()),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(resident.username ?? "---"),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Row(
                            children: [_EditButton(resident, this)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];

            return SliverMainAxisGroup(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(5),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        AdminMonitorWidget(
                          state: state,
                          pushNamed: pushNamedAndRefresh,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outlined),
                              label: Text("${AppLocale.DeleteAccount.getString(context)} (${queryLoader.selected.length})"),
                              onPressed: () async {
                                if (!_actionLock.locked && queryLoader.selected.isNotEmpty) {
                                  final content = queryLoader.selected.length == 1 ? AppLocale.Delete1ResidentAccount : AppLocale.DeleteNResidentAccounts;
                                  final fmt = content.getString(context).replaceFirst("{n}", queryLoader.selected.length.toString());

                                  final confirm = await showConfirmDialog(
                                    context: context,
                                    title: Text(AppLocale.Confirm.getString(context)),
                                    content: Text(fmt),
                                  );
                                  if (confirm) {
                                    await _deleteAccounts();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_outlined),
                              onPressed: () {
                                if (pagination.offset > 0) {
                                  pagination.offset--;
                                  reload();
                                }
                              },
                            ),
                            FutureBuilder(
                              future: pagination.future,
                              builder: (context, _) {
                                final offset = pagination.offset, offsetLimit = pagination.offsetLimit;
                                return Text("${offset + 1}/${max(offset, offsetLimit) + 1}");
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_outlined),
                              onPressed: () {
                                if (pagination.offset < pagination.offsetLimit) {
                                  pagination.offset++;
                                  reload();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_outlined),
                              onPressed: () {
                                pagination.offset = 0;
                                reload();
                              },
                            ),
                            AdminAccountSearchButton(
                              getName: () => name,
                              getRoom: () => room,
                              getUsername: () => username,
                              setName: (value) => name = value,
                              setRoom: (value) => room = value,
                              setUsername: (value) => username = value,
                              getSearching: () => searching,
                              setPageOffset: (value) => pagination.offset = value,
                              reload: reload,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: Center(child: _notification)),
                SliverPadding(
                  padding: const EdgeInsets.all(5),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: max(mediaQuery.size.width, 1000),
                        padding: const EdgeInsets.all(5),
                        child: Table(children: rows),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SliverErrorFullScreen(errorCode: code, callback: reload);
        },
      ),
    );
  }
}
