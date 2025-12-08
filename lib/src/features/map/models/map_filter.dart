class MapFilter {
  final bool includeApartments;
  final bool includeVillas;
  final bool includeBuildings;
  final int minPrice;
  final int maxPrice;
  final int minArea;
  final int maxArea;

  const MapFilter({
    this.includeApartments = true,
    this.includeVillas = true,
    this.includeBuildings = true,
    this.minPrice = 0,
    this.maxPrice = 10000000,
    this.minArea = 0,
    this.maxArea = 1000,
  });

  MapFilter copyWith({
    bool? includeApartments,
    bool? includeVillas,
    bool? includeBuildings,
    int? minPrice,
    int? maxPrice,
    int? minArea,
    int? maxArea,
  }) {
    return MapFilter(
      includeApartments: includeApartments ?? this.includeApartments,
      includeVillas: includeVillas ?? this.includeVillas,
      includeBuildings: includeBuildings ?? this.includeBuildings,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
    );
  }
} 