import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  String get _unitId {
    // Test IDs from Google
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }
  

  @override
  void initState() {
    super.initState();
    
    _loadAd();
  }

  void _loadAd() {

    if(_unitId.isEmpty) return;

    _ad = BannerAd(
      adUnitId: _unitId,
      request: const AdRequest(),
      size: AdSize.banner,  // 320x50
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(  
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}