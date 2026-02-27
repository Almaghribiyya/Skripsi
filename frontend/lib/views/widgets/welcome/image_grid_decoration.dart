import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';

// Grid gambar dekoratif 3 kolom dengan item tengah digeser ke bawah
class ImageGridDecoration extends StatelessWidget {
  const ImageGridDecoration({super.key});

  static const List<String> _imageUrls = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCVOptLAusmN327SYx89z3rQXDj9GBpZC8xFLDlY4Min9DBbc6zBTcUMiOBZZKmSdM0XRaZealHSw2-5aPTBWXgjFzEBf5gFU64b-1pabTenwlBQcdpBCFPXuwjqvEXnBl9JRP1ff5gbAHSQVQODD7DDSNpDNeXvu44kvBT82Lw9waoez2__a0yZGHN8h6safVRWY6HK1VzA5gZkvie7dgY3P-JnA4Nx1F3B1P847riXY94k4-AlFlCxnUbfu76RCtT8y3XvCSzH-Y',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBWtlj0_ZCiygpzYrlayGEES31XhX1OU_NzfRIzi-90GRRZMVBQaCdqzWQtAs6VOVxPQ1ewTjIXm087slPu7D5EY0XsiWkzm79zEpDShc0wTH74JFbNgGmGb6wQoZmHeaxtZMcbF_KYBeoKJJ_Eqn_TyEuBuCZSiuWkomceh-zAk-4EX7tLKsFcwnILhf67wAwPUEecZ1lPW5WOWebT0ryecDhBlWYcD5P_eDyoSXlL0C8ArzGIAykAnLayvpGqrw8OBuENYdQ5AQk',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBoq5vvmUDbonnDDqvNSb-eAhlj2MBsGqkBqc561zNGc5eohV0qdvjr-ym7cyOIN-2D2dF5Se2_Uvn86slKvwgrioX0gXxE9hQOkNejz0wTr4Pp3NOoojmm1gWtSElyMaIPOIuLKAAAu95IdRVxJH-doUiH90yW13g2oAoU6NCnCOpiRBiG8rcXAjGX9VHz1Raevty4DVjHhvRYI3DtDN90rI1wQ-ryjJJJpufiLjftE_lDURIFlXswFom1NIr2IeEdkBPqehNaZV0',
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.translate(
                  // item tengah digeser 16px ke bawah
                  offset: Offset(0, index == 1 ? 16 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Opacity(
                          opacity: 0.70,
                          child: CachedNetworkImage(
                            imageUrl: _imageUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 96,
                            placeholder: (context, url) => Container(
                              color: AppColors.surfaceDark,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceDark,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textMutedDark,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
