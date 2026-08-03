class City {
  final String id;
  final String name;
  final String state;
  final bool isActive;

  City({
    required this.id,
    required this.name,
    required this.state,
    required this.isActive,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'state': state, 'isActive': isActive};
  }
}

class Sport {
  final String id;
  final String name;
  final String? iconUrl;
  final bool isActive;

  Sport({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.isActive,
  });

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      id: json['id'] as String,
      name: json['name'] as String,
      iconUrl: json['iconUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'iconUrl': iconUrl, 'isActive': isActive};
  }
}

class Amenity {
  final String id;
  final String name;
  final String? iconUrl;

  Amenity({required this.id, required this.name, this.iconUrl});

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'] as String,
      name: json['name'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'iconUrl': iconUrl};
  }
}

class TurfImage {
  final String id;
  final String url;
  final String? publicId;

  TurfImage({required this.id, required this.url, this.publicId});

  factory TurfImage.fromJson(Map<String, dynamic> json) {
    return TurfImage(
      id: json['id'] as String,
      url: json['url'] as String,
      publicId: json['publicId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'url': url, 'publicId': publicId};
  }
}

class Slot {
  final String id;
  final String courtId;
  final String date;
  final String startTime;
  final String endTime;
  final double price;
  final String status;

  Slot({
    required this.id,
    required this.courtId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      id: json['id'] as String,
      courtId: json['courtId'] as String,
      date: json['date'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courtId': courtId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'price': price,
      'status': status,
    };
  }
}

class Court {
  final String id;
  final String turfId;
  final String name;
  final String type;
  final List<Sport> sports;
  final double pricePerHour;
  final bool isActive;

  Court({
    required this.id,
    required this.turfId,
    required this.name,
    required this.type,
    required this.sports,
    required this.pricePerHour,
    required this.isActive,
  });

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(
      id: json['id'] as String,
      turfId: json['turfId'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      sports:
          (json['sports'] as List<dynamic>?)
              ?.map((e) => Sport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pricePerHour: (json['pricePerHour'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'turfId': turfId,
      'name': name,
      'type': type,
      'sports': sports.map((e) => e.toJson()).toList(),
      'pricePerHour': pricePerHour,
      'isActive': isActive,
    };
  }
}

class Turf {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String cityId;
  final City? city;
  final double? lat;
  final double? lng;
  final List<TurfImage> images;
  final List<Amenity> amenities;
  final List<Court> courts;
  final double basePricePerHour;
  final String status;
  final String openingTime;
  final String closingTime;
  final int slotDurationMinutes;

  Turf({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.cityId,
    this.city,
    this.lat,
    this.lng,
    required this.images,
    required this.amenities,
    required this.courts,
    required this.basePricePerHour,
    required this.status,
    required this.openingTime,
    required this.closingTime,
    required this.slotDurationMinutes,
  });

  factory Turf.fromJson(Map<String, dynamic> json) {
    return Turf(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      address: json['address'] as String,
      cityId: json['cityId'] as String,
      city: json['city'] != null
          ? City.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => TurfImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      amenities:
          (json['amenities'] as List<dynamic>?)
              ?.map((e) => Amenity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      courts:
          (json['courts'] as List<dynamic>?)
              ?.map((e) => Court.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      basePricePerHour: (json['basePricePerHour'] as num).toDouble(),
      status: json['status'] as String,
      openingTime: json['openingTime'] as String,
      closingTime: json['closingTime'] as String,
      slotDurationMinutes: json['slotDurationMinutes'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'cityId': cityId,
      if (city != null) 'city': city!.toJson(),
      'lat': lat,
      'lng': lng,
      'images': images.map((e) => e.toJson()).toList(),
      'amenities': amenities.map((e) => e.toJson()).toList(),
      'courts': courts.map((e) => e.toJson()).toList(),
      'basePricePerHour': basePricePerHour,
      'status': status,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'slotDurationMinutes': slotDurationMinutes,
    };
  }
}
