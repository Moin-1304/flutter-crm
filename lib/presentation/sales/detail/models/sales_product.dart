

// Models and item state
class Product {
  final String id;
  final String name;
  final String manufacturer;
  final double rate;
  final String uom;
  final int availableQty;

  const Product({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.rate,
    required this.uom,
    required this.availableQty,
  });
}

class Customer {
  final String code;
  final String name;
  final String address;

  const Customer({required this.code, required this.name, required this.address});
}