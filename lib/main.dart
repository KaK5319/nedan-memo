import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'seal.dart';

const kCream = Color(0xFFF7EFE3);
const kCard = Color(0xFFFFFDF8);
const kAccent = Color(0xFFD84A35);
const kPriceRed = Color(0xFFD32F2F);
const kTextDark = Color(0xFF2B2118);
const kTextSub = Color(0xFF8A7A6A);

void main() {
  runApp(const NedanMemoApp());
}

class NedanMemoApp extends StatefulWidget {
  const NedanMemoApp({super.key});

  @override
  State<NedanMemoApp> createState() => _NedanMemoAppState();
}

class _NedanMemoAppState extends State<NedanMemoApp> {
  final DataStore store = DataStore();
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '値段メモ',
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: kCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kCream,
          foregroundColor: kTextDark,
          elevation: 0,
          centerTitle: true,
        ),
        fontFamily: null,
      ),
      home: loaded
          ? HomeScreen(store: store)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

/// 「＋ 商品を登録」ボタン（ホーム・お店ページ共通）
Widget registerButton(BuildContext context, DataStore store,
    {String? storeName}) {
  return FloatingActionButton.extended(
    backgroundColor: kAccent,
    foregroundColor: Colors.white,
    onPressed: () => showRegisterSheet(context, store, storeName: storeName),
    icon: const Icon(Icons.add),
    label: const Text('商品を登録',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  );
}

/// 写真の表示（無い場合はプレースホルダ）
Widget photoThumb(DataStore store, PriceRecord record,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final f = store.photoFileSync(record.photo);
  if (f == null) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEDE4D3),
      child: const Icon(Icons.image_outlined, color: kTextSub, size: 28),
    );
  }
  return Image.file(f, width: width, height: height, fit: fit);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final DataStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool byStore = true; // 開いた時は常に「店ごと」
  String query = '';

  DataStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('値段メモ')),
      floatingActionButton: registerButton(context, store),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '商品名で検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: kCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (v) => setState(() => query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _toggle(),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) =>
                  byStore ? _storeList() : _productList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? kCard : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? kTextDark : kTextSub,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE5D2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          seg('店ごと', byStore, () => setState(() => byStore = true)),
          seg('商品ごと', !byStore, () => setState(() => byStore = false)),
        ],
      ),
    );
  }

  Widget _storeList() {
    var names = store.storeNames();
    if (query.isNotEmpty) {
      names = names
          .where((n) => store.recordsOfStore(n).any((r) =>
              (store.productById(r.productId)?.name ?? '').contains(query)))
          .toList();
    }
    if (names.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty
              ? 'まだ登録がありません\n「＋ 商品を登録」から登録してください'
              : '合うお店がありません',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextSub, fontSize: 15),
        ),
      );
    }
    // 実店舗を先に並べ、ネットのお店は入口カードから専用ページで開く
    final physical = names.where((n) => !store.isOnline(n)).toList();
    final online = names.where((n) => store.isOnline(n)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        for (final name in physical) buildStoreCard(context, store, name),
        if (online.isNotEmpty) _onlineEntranceCard(online),
      ],
    );
  }

  /// ネットのお店への入口カード（タップで専用ページを開く）
  Widget _onlineEntranceCard(List<String> online) {
    var total = 0;
    for (final n in online) {
      total += store.recordsOfStore(n).length;
    }
    return Card(
      color: kCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnlineStoresPage(store: store, query: query),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8CF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront,
                    color: Color(0xFF9A7B4F), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text('ネットのお店',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kTextDark)),
                        ),
                        const SizedBox(width: 8),
                        netBadge(),
                      ],
                    ),
                    Text('${online.length}店・$total件',
                        style: const TextStyle(fontSize: 13, color: kTextSub)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kTextSub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productList() {
    final ps = store.products
        .where((p) => query.isEmpty || p.name.contains(query))
        .toList();
    if (ps.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? 'まだ商品がありません' : '合う商品はありません',
          style: const TextStyle(color: kTextSub, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: ps.length,
      itemBuilder: (context, i) => ProductCard(store: store, product: ps[i]),
    );
  }
}

/// 「ネット」バッジ（お店カード・入口カード共通）
Widget netBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF5B7C99),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text('ネット',
        style: TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
  );
}

/// お店カード（お店一覧・ネットのお店ページ共通）
Widget buildStoreCard(BuildContext context, DataStore store, String name) {
  final count = store.recordsOfStore(name).length;
  return Card(
    color: kCard,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StorePage(store: store, storeName: name),
        ),
      ),
      onLongPress: () => showStoreMenuSheet(context, store, name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8CF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront,
                  color: Color(0xFF9A7B4F), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kTextDark)),
                      ),
                      if (store.isOnline(name)) ...[
                        const SizedBox(width: 8),
                        netBadge(),
                      ],
                    ],
                  ),
                  Text('$count件',
                      style: const TextStyle(fontSize: 13, color: kTextSub)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextSub),
          ],
        ),
      ),
    ),
  );
}

/// ネットのお店だけを並べる専用ページ（お店一覧の入口カードから開く）
class OnlineStoresPage extends StatelessWidget {
  const OnlineStoresPage({super.key, required this.store, required this.query});

  final DataStore store;

  /// お店一覧の検索文字列（一覧と同じ条件で絞り込む）
  final String query;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // お店一覧と同じ検索条件で、ネットのお店だけを取り出す
        var names = store.storeNames().where((n) => store.isOnline(n)).toList();
        if (query.isNotEmpty) {
          names = names
              .where((n) => store.recordsOfStore(n).any((r) =>
                  (store.productById(r.productId)?.name ?? '').contains(query)))
              .toList();
        }
        var total = 0;
        for (final n in names) {
          total += store.recordsOfStore(n).length;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('値段メモ')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('お店一覧に戻る'),
                  style: TextButton.styleFrom(
                    foregroundColor: kTextDark,
                    backgroundColor: kCard,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.storefront,
                      color: Color(0xFF9A7B4F), size: 26),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('ネットのお店',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kTextDark)),
                  ),
                  Text('${names.length}店・$total件',
                      style: const TextStyle(fontSize: 14, color: kTextSub)),
                ],
              ),
              const SizedBox(height: 14),
              if (names.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text('ネットのお店はまだありません',
                        style: TextStyle(color: kTextSub, fontSize: 15)),
                  ),
                )
              else
                for (final name in names) buildStoreCard(context, store, name),
            ],
          ),
        );
      },
    );
  }
}

/// 商品ごと表示の商品カード
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.store, required this.product});

  final DataStore store;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final recs = store.recordsOfProduct(product.id)
      ..sort((a, b) => a.price.compareTo(b.price));
    return Card(
      color: kCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(product.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kTextDark)),
                ),
                OutlinedButton(
                  onPressed: () =>
                      showProductEditSheet(context, store, product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextDark,
                    side: const BorderSide(color: Color(0xFFD8CBB2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                  child: const Text('編集'),
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFEFE5D2)),
            for (final r in recs) _recordRow(context, r),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(BuildContext context, PriceRecord r) {
    final cheapest = store.isCheapest(r);
    return InkWell(
      onTap: () => showRecordEditSheet(context, store, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final f = store.photoFileSync(r.photo);
                if (f != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PhotoViewerPage(title: product.name, file: f),
                  ));
                }
              },
              onLongPress: () => showRecordDeleteSheet(context, store, r),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: photoThumb(store, r, width: 54, height: 54),
                  ),
                  if (cheapest)
                    const Positioned(
                      top: -8,
                      right: -8,
                      child: SaianSeal(size: 30),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.storeName,
                      style:
                          const TextStyle(fontSize: 15, color: kTextDark)),
                  Text(formatDateJa(r.date),
                      style: const TextStyle(fontSize: 12, color: kTextSub)),
                ],
              ),
            ),
            Text(
              '${r.price}円',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: cheapest ? kPriceRed : kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// お店のページ
class StorePage extends StatelessWidget {
  const StorePage({super.key, required this.store, required this.storeName});

  final DataStore store;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final recs = store.recordsOfStore(storeName);
        final intro = store.intros[storeName];
        return Scaffold(
          appBar: AppBar(title: const Text('値段メモ')),
          floatingActionButton:
              registerButton(context, store, storeName: storeName),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('お店一覧に戻る'),
                  style: TextButton.styleFrom(
                    foregroundColor: kTextDark,
                    backgroundColor: kCard,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.storefront,
                      color: Color(0xFF9A7B4F), size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(storeName,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kTextDark)),
                  ),
                  Text('${recs.length}件',
                      style: const TextStyle(fontSize: 14, color: kTextSub)),
                ],
              ),
              const SizedBox(height: 12),
              _introCard(context, intro),
              const SizedBox(height: 14),
              if (recs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text('このお店の商品はまだありません',
                        style: TextStyle(color: kTextSub, fontSize: 15)),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: recs.length,
                  itemBuilder: (context, i) => _tile(context, recs[i]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _introCard(BuildContext context, StoreIntro? intro) {
    final filled = intro != null && !intro.isEmpty;
    Widget line(String label, String value, {VoidCallback? onTap}) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: kTextSub)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: onTap != null ? const Color(0xFF1565C0) : kTextDark,
                    decoration:
                        onTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[
      Row(
        children: [
          const Expanded(
            child: Text('お店の紹介',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextDark)),
          ),
          TextButton(
            onPressed: () => showIntroEditSheet(context, store, storeName),
            child: Text(filled ? '紹介を直す' : '紹介を書く'),
          ),
        ],
      ),
    ];
    if (!filled) {
      children.add(const Text('紹介はまだありません',
          style: TextStyle(fontSize: 14, color: kTextSub)));
    } else {
      final it = intro!;
      if (it.hours.isNotEmpty) children.add(line('営業時間', it.hours));
      if (it.address.isNotEmpty) children.add(line('住所', it.address));
      if (it.phone.isNotEmpty) {
        children.add(line('電話番号', it.phone, onTap: () async {
          final uri = Uri(scheme: 'tel', path: it.phone);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }));
      }
      if (it.memo.isNotEmpty) children.add(line('メモ', it.memo));
    }

    return Card(
      color: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, PriceRecord r) {
    final product = store.productById(r.productId);
    final cheapest = store.isCheapest(r);
    return Card(
      color: kCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => showRecordEditSheet(context, store, r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        final f = store.photoFileSync(r.photo);
                        if (f != null) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PhotoViewerPage(
                                title: product?.name ?? '', file: f),
                          ));
                        }
                      },
                      onLongPress: () =>
                          showRecordDeleteSheet(context, store, r),
                      child: photoThumb(store, r),
                    ),
                  ),
                  if (cheapest)
                    const Positioned(
                      top: -6,
                      right: -6,
                      child: SaianSeal(size: 42),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product?.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                          height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.price}円',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cheapest ? kPriceRed : kTextDark,
                      ),
                    ),
                    Text(
                      formatDateJa(r.date),
                      style: const TextStyle(fontSize: 11, color: kTextSub),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 写真ビューア（写真自体のタップでは閉じない・2本指で拡大できる）
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.title, required this.file});

  final String title;
  final File file;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _isZoomed =>
      _transformController.value.getMaxScaleOnAxis() > 1.01;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // 拡大中は背景タップで閉じない（閉じるのは✕ボタン）
                if (!_isZoomed) Navigator.of(context).pop();
              },
              child: Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.file(widget.file, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 44,
            left: 16,
            child: Text(widget.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Positioned(
            top: 32,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// シート共通の土台
Widget sheetShell(BuildContext context, String title, List<Widget> children) {
  return Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: kTextDark)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          ...children,
        ],
      ),
    ),
  );
}

InputDecoration fieldDeco(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: kCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD8CBB2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD8CBB2)),
    ),
  );
}

Widget saveButton(String label, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );
}

Future<File?> pickPhoto() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  final path = result?.files.single.path;
  if (path == null) return null;
  return File(path);
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

/// 商品を登録するシート
void showRegisterSheet(BuildContext context, DataStore store,
    {String? storeName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RegisterSheet(store: store, initialStore: storeName ?? ''),
  );
}

class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key, required this.store, required this.initialStore});

  final DataStore store;
  final String initialStore;

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final nameCtrl = TextEditingController();
  late final storeCtrl = TextEditingController(text: widget.initialStore);
  final priceCtrl = TextEditingController();
  File? picked;

  @override
  void dispose() {
    nameCtrl.dispose();
    storeCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final names = <String>[];
    for (final p in store.products) {
      if (!names.contains(p.name)) names.add(p.name);
    }
    final q = nameCtrl.text.trim();
    final chips =
        names.where((n) => q.isEmpty || n.contains(q)).toList();
    return sheetShell(context, '商品を登録', [
      const Text('写真', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final f = await pickPhoto();
          if (f != null) setState(() => picked = f);
        },
        child: Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8CBB2)),
          ),
          child: picked != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(picked!, fit: BoxFit.cover),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: kTextSub, size: 32),
                    SizedBox(height: 6),
                    Text('タップして写真を選ぶ',
                        style: TextStyle(color: kTextSub)),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: nameCtrl,
        decoration: fieldDeco('商品名'),
        onChanged: (_) => setState(() {}),
      ),
      if (chips.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('登録済みの商品',
            style: TextStyle(fontSize: 12, color: kTextSub)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final n in chips)
              ActionChip(
                label: Text(n),
                backgroundColor: kCard,
                onPressed: () =>
                    setState(() => nameCtrl.text = n),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      TextField(controller: storeCtrl, decoration: fieldDeco('店名')),
      const SizedBox(height: 12),
      TextField(
        controller: priceCtrl,
        decoration: fieldDeco('値段（円）'),
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 18),
      saveButton('保存する', () async {
        final name = nameCtrl.text.trim();
        final storeName = storeCtrl.text.trim();
        final price = int.tryParse(priceCtrl.text.trim());
        if (name.isEmpty) {
          showSnack(context, '商品名を入れてください');
          return;
        }
        if (storeName.isEmpty) {
          showSnack(context, '店名を入れてください');
          return;
        }
        if (price == null) {
          showSnack(context, '値段を入れてください');
          return;
        }
        await store.addRecord(
          productName: name,
          storeName: storeName,
          price: price,
          date: formatDateIso(DateTime.now()),
          photoSrc: picked,
        );
        if (context.mounted) Navigator.of(context).pop();
      }),
    ]);
  }
}

/// 商品の編集シート（写真欄は無い。写真は記録ごとに持つ）
void showProductEditSheet(
    BuildContext context, DataStore store, Product product) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ProductEditSheet(store: store, product: product),
  );
}

class ProductEditSheet extends StatefulWidget {
  const ProductEditSheet({super.key, required this.store, required this.product});

  final DataStore store;
  final Product product;

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  late final nameCtrl = TextEditingController(text: widget.product.name);

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final product = widget.product;
    return sheetShell(context, '商品を編集', [
      TextField(controller: nameCtrl, decoration: fieldDeco('商品名')),
      const SizedBox(height: 8),
      const Text('写真は、お店ごとの記録から変更できます',
          style: TextStyle(fontSize: 13, color: kTextSub)),
      const SizedBox(height: 18),
      saveButton('保存する', () async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) {
          showSnack(context, '商品名を入れてください');
          return;
        }
        product.name = name;
        await store.changed();
        if (context.mounted) Navigator.of(context).pop();
      }),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('削除しますか？'),
                content:
                    Text('「${product.name}」と、その値段の記録をすべて削除します'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('やめる'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(true),
                    style: TextButton.styleFrom(foregroundColor: kPriceRed),
                    child: const Text('削除する'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await store.deleteProduct(product);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: kPriceRed,
            side: const BorderSide(color: kPriceRed),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('この商品を削除',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

/// 記録の編集シート
void showRecordEditSheet(
    BuildContext context, DataStore store, PriceRecord record) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RecordEditSheet(store: store, record: record),
  );
}

class RecordEditSheet extends StatefulWidget {
  const RecordEditSheet({super.key, required this.store, required this.record});

  final DataStore store;
  final PriceRecord record;

  @override
  State<RecordEditSheet> createState() => _RecordEditSheetState();
}

class _RecordEditSheetState extends State<RecordEditSheet> {
  late final storeCtrl =
      TextEditingController(text: widget.record.storeName);
  late final priceCtrl =
      TextEditingController(text: widget.record.price.toString());
  late DateTime date =
      DateTime.tryParse(widget.record.date) ?? DateTime.now();
  File? newPicked;
  bool photoRemoved = false;

  @override
  void dispose() {
    storeCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final record = widget.record;
    final existing =
        photoRemoved ? null : store.photoFileSync(record.photo);
    return sheetShell(context, '記録を編集', [
      const Text('写真（この写真は、このお店の記録だけに付きます）',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8CBB2)),
        ),
        child: newPicked != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(newPicked!, fit: BoxFit.cover),
              )
            : existing != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(existing, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, color: kTextSub, size: 32),
                      SizedBox(height: 6),
                      Text('写真はありません', style: TextStyle(color: kTextSub)),
                    ],
                  ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final f = await pickPhoto();
              if (f != null) {
                setState(() {
                  newPicked = f;
                  photoRemoved = false;
                });
              }
            },
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('写真を選ぶ'),
          ),
          const SizedBox(width: 8),
          if (newPicked != null || existing != null)
            OutlinedButton.icon(
              onPressed: () => setState(() {
                newPicked = null;
                photoRemoved = true;
              }),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('写真を外す'),
              style:
                  OutlinedButton.styleFrom(foregroundColor: kPriceRed),
            ),
        ],
      ),
      const SizedBox(height: 14),
      TextField(controller: storeCtrl, decoration: fieldDeco('店名')),
      const SizedBox(height: 12),
      TextField(
        controller: priceCtrl,
        decoration: fieldDeco('値段（円）'),
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('日付', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Text(formatDateJa(formatDateIso(date)),
              style: const TextStyle(fontSize: 15)),
          const Spacer(),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                locale: const Locale('ja'),
              );
              if (d != null) setState(() => date = d);
            },
            child: const Text('日付を変更'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      saveButton('保存する', () async {
        final storeName = storeCtrl.text.trim();
        final price = int.tryParse(priceCtrl.text.trim());
        if (storeName.isEmpty) {
          showSnack(context, '店名を入れてください');
          return;
        }
        if (price == null) {
          showSnack(context, '値段を入れてください');
          return;
        }
        record.storeName = storeName;
        record.price = price;
        record.date = formatDateIso(date);
        if (newPicked != null) {
          await store.setRecordPhoto(record, newPicked!);
        } else if (photoRemoved) {
          await store.clearRecordPhoto(record);
        }
        await store.changed();
        if (context.mounted) Navigator.of(context).pop();
      }),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('削除しますか？'),
                content: Text(
                    '${record.storeName}の記録（${record.price}円）を削除します'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: const Text('やめる'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(c).pop(true),
                    style: TextButton.styleFrom(foregroundColor: kPriceRed),
                    child: const Text('削除する'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await store.deleteRecord(record);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: kPriceRed,
            side: const BorderSide(color: kPriceRed),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('この記録を削除',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

/// 写真長押しの「削除しますか？」シート
void showRecordDeleteSheet(
    BuildContext context, DataStore store, PriceRecord record) {
  final product = store.productById(record.productId);
  final count =
      product == null ? 0 : store.recordsOfProduct(product.id).length;
  showModalBottomSheet(
    context: context,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('削除しますか？',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kTextDark)),
            const SizedBox(height: 4),
            Text('「${product?.name ?? ''}」',
                style: const TextStyle(fontSize: 15, color: kTextDark)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(c).pop();
                  await store.deleteRecord(record);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPriceRed,
                  side: const BorderSide(color: kPriceRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Column(
                  children: [
                    Text('${record.storeName}の記録だけ削除',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '${record.price}円・${formatDateJa(record.date)}',
                      style: const TextStyle(fontSize: 12, color: kTextSub),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(c).pop();
                  if (product != null) await store.deleteProduct(product);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPriceRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Column(
                  children: [
                    const Text('商品をすべて削除',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '値段の記録$count件も全部消えます',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(c).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: kTextDark,
                  backgroundColor: const Color(0xFFEFE5D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('やめる',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// お店のメニューシート（お店カード長押し）
void showStoreMenuSheet(BuildContext context, DataStore store, String name) {
  final online = store.isOnline(name);
  showModalBottomSheet(
    context: context,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kTextDark)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(c).pop();
                  showRenameStoreSheet(context, store, name);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextDark,
                  side: const BorderSide(color: Color(0xFFD8CBB2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('お店の名前を変更',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(c).pop();
                  await store.setStoreOnline(name, !online);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextDark,
                  side: const BorderSide(color: Color(0xFFD8CBB2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(online ? '実店舗に戻す' : 'ネットのお店にする',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(c).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: kTextDark,
                  backgroundColor: const Color(0xFFEFE5D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('やめる',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// お店の名前を変更するシート（お店メニューから開く）
void showRenameStoreSheet(
    BuildContext context, DataStore store, String oldName) {
  final ctrl = TextEditingController(text: oldName);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => sheetShell(c, 'お店の名前を変更', [
      TextField(controller: ctrl, decoration: fieldDeco('店名')),
      const SizedBox(height: 18),
      saveButton('変更する', () async {
        final name = ctrl.text.trim();
        if (name.isEmpty) {
          showSnack(c, '店名を入れてください');
          return;
        }
        await store.renameStore(oldName, name);
        if (c.mounted) Navigator.of(c).pop();
      }),
    ]),
  );
}

/// お店の紹介を書く・直すシート
void showIntroEditSheet(
    BuildContext context, DataStore store, String storeName) {
  final intro = store.intros[storeName] ?? StoreIntro();
  final hoursCtrl = TextEditingController(text: intro.hours);
  final addressCtrl = TextEditingController(text: intro.address);
  final phoneCtrl = TextEditingController(text: intro.phone);
  final memoCtrl = TextEditingController(text: intro.memo);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => sheetShell(c, 'お店の紹介', [
      TextField(controller: hoursCtrl, decoration: fieldDeco('営業時間')),
      const SizedBox(height: 12),
      TextField(controller: addressCtrl, decoration: fieldDeco('住所')),
      const SizedBox(height: 12),
      TextField(
        controller: phoneCtrl,
        decoration: fieldDeco('電話番号'),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: memoCtrl,
        decoration: fieldDeco('メモ'),
        maxLines: 3,
      ),
      const SizedBox(height: 18),
      saveButton('保存する', () async {
        store.intros[storeName] = StoreIntro(
          hours: hoursCtrl.text.trim(),
          address: addressCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          memo: memoCtrl.text.trim(),
        );
        await store.changed();
        if (c.mounted) Navigator.of(c).pop();
      }),
    ]),
  );
}
