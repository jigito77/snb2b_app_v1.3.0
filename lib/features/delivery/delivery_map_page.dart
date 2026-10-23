import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/di.dart';
import '../../core/errors/app_exception.dart';
import '../../core/l10n/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import 'delivery_models.dart';

/// Выбор точки доставки на карте (OpenStreetMap — тот же провайдер, что на сайте).
/// Можно: взять текущее местоположение, найти адрес, нажать на карту. Возвращает [GeoPoint]
/// (широта, долгота, адрес) через Navigator.pop. Расстояние и стоимость считает backend.
class DeliveryMapPage extends ConsumerStatefulWidget {
  const DeliveryMapPage({super.key, this.initial});

  final GeoPoint? initial;

  static Future<GeoPoint?> open(BuildContext context, {GeoPoint? initial}) {
    return Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute<GeoPoint>(builder: (_) => DeliveryMapPage(initial: initial)),
    );
  }

  @override
  ConsumerState<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends ConsumerState<DeliveryMapPage> {
  // Центр по умолчанию — Ереван (точка отправки магазина).
  static const LatLng _fallbackCenter = LatLng(40.1792, 44.4991);

  final MapController _map = MapController();
  final TextEditingController _query = TextEditingController();
  Timer? _searchTimer;

  LatLng? _point;
  String _address = '';
  bool _resolving = false;
  bool _locating = false;
  bool _searching = false;
  List<GeoPoint> _results = const <GeoPoint>[];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _point = LatLng(i.lat, i.lng);
      _address = i.address;
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _setPoint(LatLng p, {String? address, bool move = false}) async {
    setState(() {
      _point = p;
      _results = const <GeoPoint>[];
      if (address != null) _address = address;
      _resolving = address == null;
      if (address == null) _address = '';
    });
    if (move) _map.move(p, 14);
    if (address != null) return;
    try {
      final text = await ref.read(ordersRepositoryProvider).reverseGeocode(p.latitude, p.longitude);
      if (!mounted || _point != p) return;
      setState(() {
        _address = text;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Адрес можно не найти — координаты всё равно сохранятся, сервер посчитает доставку по ним.
      setState(() => _resolving = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const AppException.validation('Включите геолокацию на устройстве.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw const AppException.validation('Нет доступа к местоположению. Выберите точку на карте или найдите адрес.');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await _setPoint(LatLng(pos.latitude, pos.longitude), move: true);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onQueryChanged(String value) {
    _searchTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => _results = const <GeoPoint>[]);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      try {
        final list = await ref.read(ordersRepositoryProvider).searchAddress(value.trim());
        if (!mounted) return;
        setState(() => _results = list);
      } catch (e) {
        if (mounted) showSnack(context, errorMessage(e), error: true);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pick(GeoPoint g) {
    FocusScope.of(context).unfocus();
    _query.text = g.address;
    unawaited(_setPoint(LatLng(g.lat, g.lng), address: g.address, move: true));
  }

  void _confirm() {
    final p = _point;
    if (p == null) {
      showSnack(context, 'Выберите точку на карте.', error: true);
      return;
    }
    Navigator.of(context).pop(GeoPoint(lat: p.latitude, lng: p.longitude, address: _address.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    return Scaffold(
      appBar: AppBar(title: const Text('Точка доставки')),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: p ?? _fallbackCenter,
              initialZoom: p == null ? 6 : 14,
              onTap: (tapPosition, latLng) => unawaited(_setPoint(latLng)),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'am.snp.shop',
              ),
              if (p != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: p,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, size: 48, color: AppColors.danger),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: <SourceAttribution>[TextSourceAttribution('© OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              children: <Widget>[
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    decoration: AppInput.of(
                      hint: 'Поиск адреса',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.card,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(_results[i].address, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _pick(_results[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 170,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _locating ? null : _locate,
              child: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                p == null
                    ? 'Нажмите на карту, найдите адрес или используйте «Моё местоположение»'
                    : (_resolving
                        ? 'Определяем адрес…'
                        : (_address.isEmpty ? 'Адрес не найден — координаты сохранятся' : _address)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body,
              ),
              if (p != null)
                Text(
                  '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                  style: AppText.caption,
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: p == null ? null : _confirm,
                child: const Text('Подтвердить точку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
