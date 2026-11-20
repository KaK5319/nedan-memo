import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 商品（名前だけを持つ。同名の商品が複数あってもよい）
class Product {
  Product({required this.id, required this.name});

  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(id: j['id'] as String, name: (j['name'] ?? '') as String);
}

/// 値段の記録（商品に属し、お店・値段・日付・その記録だけの写真を持つ）
class PriceRecord {
  PriceRecord({
    required this.id,
    required this.productId,
    required this.storeName,
    required this.price,
    required this.date,
    this.photo,
  });

  final String id;
  final String productId;
  String storeName;
  int price;

  /// yyyy-MM-dd
  String date;

  /// photos フォルダ内のファイル名（写真は記録ごとに独立）
  String? photo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'storeName': storeName,
        'price': price,
        'date': date,
        'photo': photo,
      };

  factory PriceRecord.fromJson(Map<String, dynamic> j) => PriceRecord(
        id: j['id'] as String,
        productId: j['productId'] as String,
        storeName: (j['storeName'] ?? '') as String,
        price: (j['price'] as num?)?.toInt() ?? 0,
        date: (j['date'] ?? '') as String,
        photo: j['photo'] as String?,
      );
}

/// お店の紹介（店名をキーに保存）
class StoreIntro {
  StoreIntro({this.hours = '', this.address = '', this.phone = '', this.memo = ''});

  String hours;
  String address;
  String phone;
  String memo;

  bool get isEmpty =>
      hours.isEmpty && address.isEmpty && phone.isEmpty && memo.isEmpty;

  Map<String, dynamic> toJson() =>
      {'hours': hours, 'address': address, 'phone': phone, 'memo': memo};

  factory StoreIntro.fromJson(Map<String, dynamic> j) => StoreIntro(
        hours: (j['hours'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        memo: (j['memo'] ?? '') as String,
      );
}

String formatDateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 「11月14日（土）」形式
String formatDateJa(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const wd = ['月', '火', '水', '木', '金', '土', '日'];
  return '${d.month}月${d.day}日（${wd[d.weekday - 1]}）';
}

/// データ全体の保持と、端末内JSONファイルへの保存
class DataStore extends ChangeNotifier {
  List<Product> products = [];
  List<PriceRecord> records = [];
  Map<String, StoreIntro> intros = {};

  /// ネットのお店として印を付けた店名（店名をキーに保存）
  Set<String> onlineStores = {};

  /// お店ごとに選んだアイコンのキー（店名をキーに保存）
  Map<String, String> storeIcons = {};

  Directory? _docs;
  int _counter = 0;

  String newId() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }

  Future<Directory> docsDir() async =>
      _docs ??= await getApplicationDocumentsDirectory();

  Future<File?> photoFile(String? name) async {
    if (name == null) return null;
    final d = await docsDir();
    final f = File('${d.path}/photos/$name');
    return await f.exists() ? f : null;
  }

  /// load() 後にだけ使う同期版（表示用）
  File? photoFileSync(String? name) {
    if (name == null || _docs == null) return null;
    final f = File('${_docs!.path}/photos/$name');
    return f.existsSync() ? f : null;
  }

  Future<void> load() async {
    final d = await docsDir();
    await Directory('${d.path}/photos').create(recursive: true);
    final f = File('${d.path}/nedan_memo_data.json');
    if (await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        products = ((j['products'] as List?) ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        records = ((j['records'] as List?) ?? [])
            .map((e) => PriceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        final rawIntros = (j['intros'] as Map<String, dynamic>?) ?? {};
        intros = rawIntros.map(
            (k, v) => MapEntry(k, StoreIntro.fromJson(v as Map<String, dynamic>)));
        // 旧データには無い項目なので、無ければ「ネットのお店なし」で始める
        onlineStores =
            ((j['onlineStores'] as List?) ?? []).whereType<String>().toSet();
        // 旧データには無い項目なので、無ければ「アイコン未設定」で始める
        final rawIcons = (j['storeIcons'] as Map<String, dynamic>?) ?? {};
        storeIcons = rawIcons.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        // 壊れていたら空から始める
        products = [];
        records = [];
        intros = {};
        onlineStores = {};
        storeIcons = {};
      }
    }
    notifyListeners();
  }

  Future<void> save() async {
    final d = await docsDir();
    final f = File('${d.path}/nedan_memo_data.json');
    // 記録が無くなったお店の印は落とす
    final liveStores = records.map((r) => r.storeName).toSet();
    onlineStores.removeWhere((n) => !liveStores.contains(n));
    storeIcons.removeWhere((k, _) => !liveStores.contains(k));
    final j = {
      'products': products.map((e) => e.toJson()).toList(),
      'records': records.map((e) => e.toJson()).toList(),
      'intros': intros.map((k, v) => MapEntry(k, v.toJson())),
      'onlineStores': onlineStores.toList(),
      'storeIcons': storeIcons,
    };
    await f.writeAsString(jsonEncode(j));
  }

  Future<void> changed() async {
    await save();
    notifyListeners();
  }

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<PriceRecord> recordsOfProduct(String productId) =>
      records.where((r) => r.productId == productId).toList();

  List<PriceRecord> recordsOfStore(String store) =>
      records.where((r) => r.storeName == store).toList();

  List<String> storeNames() {
    final s = records.map((r) => r.storeName).toSet().toList();
    s.sort();
    return s;
  }

  /// 同じ名前の商品グループ全体での最安値
  int minPriceForProductName(String name) {
    int? min;
    for (final r in records) {
      final p = productById(r.productId);
      if (p != null && p.name == name) {
        if (min == null || r.price < min) min = r.price;
      }
    }
    return min ?? 0;
  }

  bool isCheapest(PriceRecord r) {
    final p = productById(r.productId);
    if (p == null) return false;
    return r.price <= minPriceForProductName(p.name);
  }

  Future<String> _copyPhotoIntoApp(File src, String recordId) async {
    final d = await docsDir();
    var ext = 'jpg';
    final dot = src.path.lastIndexOf('.');
    if (dot >= 0 && dot < src.path.length - 1) {
      ext = src.path.substring(dot + 1).toLowerCase();
    }
    final name = '${recordId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await src.copy('${d.path}/photos/$name');
    return name;
  }

  Future<void> _deletePhotoFile(String? name) async {
    if (name == null) return;
    try {
      final d = await docsDir();
      final f = File('${d.path}/photos/$name');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 新しい値段を登録。同名の商品があれば先頭の商品の下に入る。
  Future<PriceRecord> addRecord({
    required String productName,
    required String storeName,
    required int price,
    required String date,
    File? photoSrc,
  }) async {
    Product? target;
    for (final p in products) {
      if (p.name == productName) {
        target = p;
        break;
      }
    }
    if (target == null) {
      target = Product(id: newId(), name: productName);
      products.add(target);
    }
    final rec = PriceRecord(
      id: newId(),
      productId: target.id,
      storeName: storeName,
      price: price,
      date: date,
    );
    if (photoSrc != null) {
      rec.photo = await _copyPhotoIntoApp(photoSrc, rec.id);
    }
    records.add(rec);
    await changed();
    return rec;
  }

  /// 記録の写真を差し替える（ファイル操作のみ。保存は呼び出し側で changed() する）
  Future<void> setRecordPhoto(PriceRecord r, File src) async {
    final old = r.photo;
    r.photo = await _copyPhotoIntoApp(src, r.id);
    await _deletePhotoFile(old);
  }

  /// 記録の写真を外す（ファイル操作のみ）
  Future<void> clearRecordPhoto(PriceRecord r) async {
    final old = r.photo;
    r.photo = null;
    await _deletePhotoFile(old);
  }

  Future<void> deleteRecord(PriceRecord r) async {
    records.removeWhere((e) => e.id == r.id);
    await _deletePhotoFile(r.photo);
    await changed();
  }

  Future<void> deleteProduct(Product p) async {
    for (final r in recordsOfProduct(p.id)) {
      await _deletePhotoFile(r.photo);
    }
    records.removeWhere((e) => e.productId == p.id);
    products.removeWhere((e) => e.id == p.id);
    await changed();
  }

  /// ネットのお店かどうか
  bool isOnline(String store) => onlineStores.contains(store);

  /// ネットのお店の印を付け外しする
  Future<void> setStoreOnline(String name, bool online) async {
    if (online) {
      onlineStores.add(name);
    } else {
      onlineStores.remove(name);
    }
    await changed();
  }

  /// お店に選ばれているアイコンのキー（未設定なら 'standard'）
  String iconKeyOf(String store) => storeIcons[store] ?? 'standard';

  /// お店のアイコンを選ぶ
  Future<void> setStoreIcon(String name, String key) async {
    storeIcons[name] = key;
    await changed();
  }

  /// お店の名前変更（記録すべてと紹介がついてくる）
  Future<void> renameStore(String oldName, String newName) async {
    if (oldName == newName || newName.isEmpty) return;
    for (final r in records) {
      if (r.storeName == oldName) r.storeName = newName;
    }
    final intro = intros.remove(oldName);
    if (intro != null && !intros.containsKey(newName)) {
      intros[newName] = intro;
    }
    // ネットのお店の印も新しい名前についてくる
    if (onlineStores.remove(oldName)) {
      onlineStores.add(newName);
    }
    // アイコンの選択も新しい名前についてくる
    final icon = storeIcons.remove(oldName);
    if (icon != null && !storeIcons.containsKey(newName)) {
      storeIcons[newName] = icon;
    }
    await changed();
  }
}
