import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';

class BirdImageCarousel extends StatefulWidget {
  const BirdImageCarousel({
    super.key,
    required this.imageUrls,
    this.thumbnailUrl,
  });

  final List<String> imageUrls;
  final String? thumbnailUrl;

  @override
  State<BirdImageCarousel> createState() => _BirdImageCarouselState();
}

class _BirdImageCarouselState extends State<BirdImageCarousel> {
  int _current = 0;
  final _controller = PageController();

  List<String> get _allUrls => [
        if (widget.thumbnailUrl != null) widget.thumbnailUrl!,
        ...widget.imageUrls,
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _allUrls;

    if (urls.isEmpty) {
      return _PlaceholderImage();
    }

    return Stack(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => _ShimmerPlaceholder(),
              errorWidget: (_, __, ___) => _PlaceholderImage(),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      color: AppColors.primary.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.flutter_dash, size: 80, color: AppColors.primary),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(height: 260, color: Colors.white),
    );
  }
}
